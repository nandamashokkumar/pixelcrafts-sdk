# Integration Guide

How to migrate an existing pixelcrafts app to the auth SDK. Two flavors — Flutter and Web — covered side by side.

## When to migrate

Migrate if any of the following is true:

- Your app currently calls `api.pixelcrafts.app/api/v1/auth/sync` (legacy path).
- Your app verifies Firebase ID tokens directly on the backend via `verifyIdToken` (Firebase Admin SDK).
- Your repo contains a hand-rolled `auth_service.dart` / `lib/auth-service.ts` / `app/api/auth/verify/route.ts`.

The migration is small but real: typically **one PR per app**, ~200 lines deleted, ~20 lines added.

---

## Flutter migration

### Before — typical legacy pattern

```dart
// lib/core/auth/auth_service.dart  (~250 lines)
class AuthService {
  final FirebaseAuth _firebase = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  // ... sign-in methods, token storage, exchange logic, refresh handling ...
}

// dio interceptor — separate file
class AuthInterceptor extends Interceptor { /* ~80 lines */ }
```

### After

**Step 1 — pubspec.yaml**

Replace these:
```yaml
firebase_auth: ^5.3.0
google_sign_in: ^6.2.0
sign_in_with_apple: ^6.1.0
flutter_secure_storage: ^9.2.2
```

With:
```yaml
pixelcrafts_auth:
  git:
    url: https://github.com/pixelcrafts-app/pixelcrafts-sdk
    path: flutter/auth
    ref: auth-flutter-v0.1.0
```

(The SDK re-exports the firebase types it needs; you still need `firebase_core` for `Firebase.initializeApp`.)

**Step 2 — bootstrap (main.dart)**

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PCAuth.configure(const PCAuthConfig(appId: 'your-app-id'));
  runApp(const MyApp());
}
```

**Step 3 — delete `lib/core/auth/auth_service.dart` and the Dio interceptor file.**

**Step 4 — replace consumers**

```dart
// before
final user = await AuthService.instance.signInWithEmail(email, pw);

// after
final user = await PCAuth.instance.signInWithEmail(email, pw);
```

```dart
// before — manual Dio interceptor
final api = Dio()..interceptors.add(AuthInterceptor());

// after
final api = Dio(BaseOptions(baseUrl: 'https://api.brand.com'))
  ..interceptors.add(PCAuth.instance.interceptor);
```

**Step 5 — router**

```dart
PCAuth.instance.authStateChanges.listen((state) {
  if (state == PCAuthState.unauthenticated) router.go('/login');
});
PCAuth.instance.onSessionExpired = () => router.go('/login');
```

**Step 6 — verify**

```sh
flutter pub get
flutter analyze
flutter test
flutter run    # walk the sign-in / sign-out / token-expiry flows
```

### Reference apps

- `lavamgam-app` — the original implementation the SDK was extracted from. Code is already in the SDK; the app itself will be migrated to use the SDK in a follow-up PR.
- `verbloom-app`, `fluentpro-app` — currently on the legacy `/auth/sync` path. These are the primary migration targets.

---

## Web migration

### Before — typical legacy pattern

```
lib/
  auth-service.ts        (~70 lines)
  auth-context.tsx       (~80 lines)
  firebase.ts
app/api/auth/verify/
  route.ts               (~100 lines, hardcoded APP_ID)
```

### After

**Step 1 — package.json**

```sh
pnpm add @pixelcrafts/auth
# firebase + react are already present as peer deps
```

**Step 2 — server route**

Replace `app/api/auth/verify/route.ts` with:

```ts
import { createAuthRoute } from "@pixelcrafts/auth/server";

export const { POST } = createAuthRoute({
  appId: process.env.PIXELCRAFTS_APP_ID!,
});
```

Add `PIXELCRAFTS_APP_ID=your-app-id` to `.env.local`.

**Step 3 — bootstrap (app/layout.tsx)**

Pick the variant that matches the app's upstream identity provider as registered in `pcauth_db.apps.authProvider`:

**Firebase upstream** (lavamgam, daypilot, etc.):

```tsx
import { configure, AuthProvider } from "@pixelcrafts/auth";
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";

configure({ appId: "your-app-id" });

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <AuthProvider upstreamSignOut={() => signOut(auth)}>
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}
```

**Supabase upstream** (themeroid, etc.):

```tsx
import { configure, AuthProvider } from "@pixelcrafts/auth";
import { supabase } from "@/lib/supabase";

configure({ appId: "your-app-id" });

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <AuthProvider upstreamSignOut={() => supabase.auth.signOut()}>
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}
```

The SDK never directly imports `firebase/auth` or `@supabase/supabase-js` — that keeps the SDK bundle small and lets each consumer ship only the provider it actually uses.

**Step 4 — delete `lib/auth-service.ts` and `lib/auth-context.tsx`.**

**Step 5 — replace consumers**

```tsx
// before
import { useAuth } from "@/lib/auth-context";

// after
import { useAuth } from "@pixelcrafts/auth";
```

The hook shape is identical except for one addition: `exchangeUpstreamToken(idToken)` — a convenience wrapper combining `exchangeToken` + `login`. Sign-in screens should switch to it:

**Firebase consumer:**

```tsx
const { exchangeUpstreamToken } = useAuth();
// after Firebase sign-in completes:
const idToken = await cred.user.getIdToken();
await exchangeUpstreamToken(idToken);
```

**Supabase consumer:**

```tsx
const { exchangeUpstreamToken } = useAuth();
// after Supabase sign-in completes:
const { data } = await supabase.auth.signInWithPassword({ email, password });
if (data.session) await exchangeUpstreamToken(data.session.access_token);
```

The function name `exchangeFirebaseToken` still works as a deprecated alias — Firebase apps that adopted the SDK before the multi-provider rename don't need to rewire to ship.

**Step 6 — verify**

```sh
pnpm typecheck
pnpm build
pnpm dev       # walk sign-in, sign-out, cross-tab sync (open in two tabs)
```

### Reference app

- `lavamgam-web` — the original implementation. Code is in the SDK; the app will switch to the SDK in a follow-up PR.

---

## Backend verifier (per brand API)

The auth SDK lives on the client. Brand backends verify the platform JWT locally via JWKS — no SDK needed there, but here's the pattern:

### Hono (most pixelcrafts backends)

```ts
import { Hono } from "hono";
import { jwt } from "hono/jwt";

const app = new Hono();
app.use("/api/*", jwt({
  jwksUri: "https://auth.pixelcrafts.app/.well-known/jwks.json",
  alg: "RS256",
}));
```

After the middleware passes, `c.get("jwtPayload")` returns the decoded claims (`sub`, `email`, `entitlements`, `appId`).

### NestJS

```ts
import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { passportJwtSecret } from "jwks-rsa";

@Module({
  imports: [
    JwtModule.register({
      verifyOptions: {
        algorithms: ["RS256"],
      },
      secretOrKeyProvider: passportJwtSecret({
        jwksUri: "https://auth.pixelcrafts.app/.well-known/jwks.json",
        cache: true,
        rateLimit: true,
      }),
    }),
  ],
})
export class AuthModule {}
```

JWKS is cached in-memory after first fetch (default 10-min TTL). No per-request gateway calls.

---

## Rollout strategy

For each app:

1. **Open PR.** Migrate one app, keep the legacy code as a comment-blocked reference until QA passes.
2. **Verify the JWKS endpoint** is reachable from your backend's deployment environment (especially behind corporate VPNs / Cloud Run egress filters).
3. **Smoke-test the full loop:** sign-in → API call → sign-out → token-expiry → cross-tab sync (web only).
4. **Delete the legacy code.** Don't leave the old `auth-service.*` files in place — they confuse future readers.
5. **Tag the SDK ref.** Pin `ref: v0.1.0` in `pubspec.yaml` / `version: 0.1.0` in `package.json`. Never use `main` or a branch.

The whole migration per app should be a one-day PR. If it's taking longer, something is off — open an issue on the SDK repo.

---

## Troubleshooting

**"@pixelcrafts/auth: configure() must be called before using the SDK"**
You're reading from the SDK before `configure()` ran. Move `configure({ appId })` to the top of your bootstrap, above any imports that touch the SDK at module load.

**Flutter — `PlatformException(sign_in_canceled)` reaches my UI**
The SDK throws `PCSignInException` with `.cancelled = true`. Filter it out at the UI layer:
```dart
try { ... } on PCSignInException catch (e) {
  if (e.cancelled) return;
  showError(e.message);
}
```

**Web — `useAuth must be used within an AuthProvider`**
You're calling `useAuth()` from a component above `<AuthProvider>`. Move the call (or the provider) so the hook is inside the tree.

**Backend returns 401 with valid JWT**
- Confirm the brand API's JWKS URI matches the gateway's actual public URL (mind staging vs prod).
- Confirm the brand backend cache hasn't outlived a key rotation — restart to flush.
- `curl https://auth.pixelcrafts.app/.well-known/jwks.json` from the brand's host — must return 200 with at least one key.

**Cross-tab sync not firing**
- Web only. Confirm both tabs are on the same origin (not `localhost` vs `127.0.0.1`).
- Confirm `<AuthProvider>` is mounted in the second tab (it is, if you wrapped `layout.tsx`).
