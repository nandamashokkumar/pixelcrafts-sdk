# Architecture

The pixelcrafts auth SDK is a thin client for the **central auth gateway** (`auth.pixelcrafts.app`). It hides one specific transaction — exchanging a Firebase ID token for a platform-issued JWT — and the bookkeeping around it.

## The end-to-end flow

```
┌────────────────┐      1. credentials       ┌────────────┐
│ Client (Flutter│ ────────────────────────▶ │  Firebase  │
│  or Web)       │ ◀──────────────────────── │   Auth     │
└────────────────┘     2. Firebase ID token  └────────────┘
       │
       │ 3. POST /auth/token
       │    x-app-id: <appId>
       │    body: { idToken }
       ▼
┌──────────────────────────────┐
│  auth.pixelcrafts.app        │
│  (pixelcrafts-api-auth)      │
│  - verifies Firebase ID      │
│  - upserts user in pcauth_db │
│  - mints RS256 JWT           │
│    with entitlements claim   │
└──────────────────────────────┘
       │
       │ 4. { accessJwt, user }
       ▼
┌────────────────┐
│ Client stores  │
│  platform JWT  │
└────────────────┘
       │
       │ 5. every API call:
       │    Authorization: Bearer <platform JWT>
       │    x-app-id: <appId>
       ▼
┌──────────────────────────────┐
│  api.brand.com (per brand)   │
│  - fetches gateway JWKS once │
│  - verifies JWT locally      │
│    (no network per request)  │
└──────────────────────────────┘
```

### Key properties

- **One identity record per user**, in `pcauth_db.users`, shared across every brand the user touches.
- **Per-app entitlements** live in `pcauth_db.entitlements` and get embedded in the JWT at mint time.
- **Brand backends are stateless on auth**: they only need the gateway's public keys (cached in-memory via JWKS) to verify. No round-trip to the gateway per request.
- **Token rotation** is handled by re-running the exchange — the SDK refreshes the Firebase ID token (Firebase auto-rotates every hour) and asks the gateway for a fresh platform JWT.

## Why a gateway, not Firebase Admin per brand

Before the auth migration, every brand backend ran Firebase Admin SDK and called `verifyIdToken` per request. Three problems:

1. **No cross-brand identity.** A user with the same email could have different `users` rows in `lavamgam-api-core` and `verbloom-api-core` — no unification.
2. **No entitlements model.** Roles + subscriptions had to be re-implemented in each brand backend.
3. **Per-request network cost.** `verifyIdToken` hits Google's public-key endpoint (cached, but still a hot path concern at scale).

The gateway solves all three: one identity, one entitlements table, one set of keys, and verification happens locally on each brand backend via JWKS.

## SDK responsibilities

| Concern | Flutter (`pixelcrafts_auth`) | Web (`@pixelcrafts/auth`) |
|---|---|---|
| Firebase sign-in (email, Google, Apple, X) | Wraps `firebase_auth` + `google_sign_in` + `sign_in_with_apple` + Twitter `OAuthProvider`. | Consumer calls `firebase/auth` directly. SDK only handles post-Firebase. |
| Gateway exchange | Direct call to `${gatewayUrl}/auth/token`. | Indirect via Next.js route handler created by `createAuthRoute()`, so the gateway URL + `x-app-id` stay server-side. |
| Token storage | `flutter_secure_storage` (keychain / EncryptedSharedPreferences). | `localStorage`, namespaced per `appId`. |
| Token attach | Dio interceptor injects `Authorization: Bearer <JWT>` + `x-app-id`. | Consumer wires `fetch` headers manually (see integration guide). |
| 401 refresh | Single-flight: concurrent 401s share one refresh call; original requests are replayed transparently. | Out of scope for v0.1 — consumer's responsibility (or use a `fetch` wrapper that handles it). |
| Session-expired hook | `PCAuth.instance.onSessionExpired = () => router.go('/login')`. | Manual: check `useAuth().token` in route guards. |
| Cross-tab sync | N/A. | `storage` event listener inside `<AuthProvider>`. |
| Sign out | Clears Firebase + Google sessions + secure storage. | Consumer-supplied `firebaseSignOut` prop, plus localStorage clear. |

## Why Flutter has more surface than Web

Two reasons:

1. **Mobile apps own their HTTP client.** Dio is universal; an interceptor is the right place to attach tokens + handle 401s.
2. **Mobile apps run for hours, web sessions are short-lived.** A 401-refresh-replay loop matters more on mobile where the session may outlive the gateway-issued token.

The Web SDK keeps the surface narrow on purpose. The 401-refresh-replay pattern doesn't generalize cleanly to `fetch` (no built-in interceptor concept; users pick `axios`, `ky`, `wretch`, RTK Query, TanStack Query — each handles retries differently). v0.1 ships the unambiguous parts; v0.2 may add a thin `pcFetch` helper if real consumers ask for it.

## Versioning + breaking changes

Both packages follow SemVer. They version independently — `pixelcrafts_auth` (Flutter) and `@pixelcrafts/auth` (Web) can be on different majors. The gateway contract is the single source of truth; SDK bumps lag gateway changes by one minor cycle.

Breaking changes ship behind a major-version bump with a 90-day deprecation cycle. The deprecation warning is logged once per session.

## What lives outside this SDK

- **Gateway server code**: `pixelcrafts/pixelcrafts-api-auth` — issues JWTs, owns `pcauth_db`.
- **Brand backend verifiers**: each brand's API repo (`lavamgam-api-core`, `verbloom-api-core`, etc.) does its own JWKS verification. There is no `@pixelcrafts/auth-server-verify` package — the verifier is ~30 lines using `jose` (Node) or `flutter_jwt_decode` (rarely needed; backends usually do this).
- **Operator console**: `pixelcrafts/pixelcrafts-web-admin` — registers apps, manages entitlements, rotates signing keys.
- **Payments**: separate. The auth JWT carries an `entitlements` claim that includes active subscriptions, but minting / billing flows live elsewhere.
