# @pixelcrafts/auth (Web)

Web SDK for the **pixelcrafts central auth gateway** (`auth.pixelcrafts.app`). **Provider-agnostic** — works with Firebase Auth or Supabase Auth upstream, whichever the app's `pcauth_db.apps.authProvider` row declares. Next.js App Router + React Context, cross-tab session sync, SSR-safe storage. Replaces ~200 lines of per-app `auth-service.ts` + `auth-context.tsx` + `/api/auth/verify/route.ts` boilerplate.

The SDK doesn't import `firebase/auth` or `@supabase/supabase-js` directly — consumers run their own SDK for sign-in screens and hand the resulting token to `exchangeUpstreamToken`. Gateway figures out the rest from the registered `authProvider`.

### Firebase consumer (lavamgam, daypilot, etc.)

```tsx
// app/layout.tsx
import { configure, AuthProvider } from "@pixelcrafts/auth";
import { signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";

configure({ appId: "lavamgam" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
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

```tsx
// app/login/page.tsx
"use client";
import { useAuth } from "@pixelcrafts/auth";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase";

export default function LoginPage() {
  const { exchangeUpstreamToken } = useAuth();

  const handleSubmit = async (email: string, password: string) => {
    const cred = await signInWithEmailAndPassword(auth, email, password);
    const idToken = await cred.user.getIdToken();
    await exchangeUpstreamToken(idToken);   // SDK handles storage + state
  };
}
```

### Supabase consumer (themeroid, etc.)

```tsx
// app/layout.tsx
import { configure, AuthProvider } from "@pixelcrafts/auth";
import { supabase } from "@/lib/supabase";

configure({ appId: "themeroid" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
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

```tsx
// app/login/page.tsx
"use client";
import { useAuth } from "@pixelcrafts/auth";
import { supabase } from "@/lib/supabase";

export default function LoginPage() {
  const { exchangeUpstreamToken } = useAuth();

  const handleSubmit = async (email: string, password: string) => {
    const { data } = await supabase.auth.signInWithPassword({ email, password });
    if (data.session) await exchangeUpstreamToken(data.session.access_token);
  };
}
```

### Server route (same for both)

```ts
// app/api/auth/verify/route.ts
import { createAuthRoute } from "@pixelcrafts/auth/server";

export const { POST } = createAuthRoute({
  appId: process.env.PIXELCRAFTS_APP_ID!,
});
```

That's the whole loop. The SDK owns: server-side gateway exchange, localStorage persistence, cross-tab sync, React Context wiring, role derivation from JWT claims. The token shape is opaque to the SDK — the gateway's per-app verifier registry decides Firebase vs Supabase vs Native.

---

## Install

```sh
npm install @pixelcrafts/auth firebase
# or
pnpm add @pixelcrafts/auth firebase
```

The SDK declares `firebase` and `react` as peer dependencies — your app owns the version. Supports `firebase` ^10 || ^11 and `react` ^18 || ^19.

### Prerequisites

1. **Firebase initialized** in your app. The SDK does not initialize Firebase — you do, in `lib/firebase.ts` (or wherever).
2. **`PIXELCRAFTS_APP_ID` env var** on the server. Must match an `apps` row in `pcauth_db` — operators register apps via `pixelcrafts-web-admin`.
3. **Two entries in `.env.local`:**
   ```
   NEXT_PUBLIC_FIREBASE_API_KEY=...
   PIXELCRAFTS_APP_ID=your-app-id
   ```
   The SDK only needs `PIXELCRAFTS_APP_ID` server-side (it never leaks to the browser — the gateway URL + `x-app-id` stay behind the route handler).

---

## Public API

### Client surface (`@pixelcrafts/auth`)

| Symbol | Purpose |
|---|---|
| `configure({ appId, gatewayUrl?, verifyRoute? })` | One-time SDK bootstrap. Call at module load. |
| `<AuthProvider upstreamSignOut={...}>` | React Context provider. Wrap your app once. `firebaseSignOut` still accepted as a deprecated alias. |
| `useAuth()` | Hook returning `{ user, token, isLoading, login, exchangeUpstreamToken, logout }`. `exchangeFirebaseToken` still exposed as a deprecated alias. |
| `exchangeToken(idToken)` | Lower-level exchange — returns `AuthResult` without storing. Accepts any upstream token (Firebase ID token or Supabase access token); the gateway's per-app verifier dispatches. |
| `getStoredToken()` / `getStoredUser()` | SSR-safe synchronous reads. |
| `clearAuth()` | Wipe both storage keys for this app. |
| `isAuthenticated()` | Boolean shortcut. |

### Server surface (`@pixelcrafts/auth/server`)

| Symbol | Purpose |
|---|---|
| `createAuthRoute({ appId, gatewayUrl?, deriveRole?, timeoutMs? })` | Factory returning `{ POST }` for `app/api/auth/verify/route.ts`. |

The split is intentional — `next/server` and `Buffer` stay out of client bundles.

---

## `useAuth()` reference

```ts
const {
  user,                     // PlatformUser | null
  token,                    // string | null (the platform JWT)
  isLoading,                // true until localStorage has been read on mount
  login,                    // (result: AuthResult) => void  — store + set state
  exchangeUpstreamToken,    // (idToken: string) => Promise<AuthResult> — Firebase ID token or Supabase access token; gateway routes
  exchangeFirebaseToken,    // deprecated alias of exchangeUpstreamToken; same function
  logout,                   // () => Promise<void> — clears local state, then upstreamSignOut
} = useAuth();
```

### `exchangeUpstreamToken(idToken)` *(also: `exchangeFirebaseToken` — deprecated alias)*

The 80% path. Call after Firebase auth completes; it:
1. POSTs to your `/api/auth/verify` route (the `createAuthRoute` handler proxies to the gateway with `x-app-id`).
2. Stores the returned platform JWT + user in `localStorage` (namespaced per `appId`).
3. Updates context state synchronously.
4. Returns the `AuthResult` for routing decisions.

### `login(result)`

Use this only when you already have an `AuthResult` (e.g. you called `exchangeToken` directly, or you're rehydrating from an external source).

### `logout()`

Clears local state first (UI updates immediately), then calls the `upstreamSignOut` prop you passed to `<AuthProvider>`. Errors from that callback are swallowed — local state must always clear.

---

## Cross-tab sync

`<AuthProvider>` listens for `storage` events on the SDK's own keys. When tab A logs in or out, tab B's `useAuth()` updates on the next React frame. Zero extra code from the consumer.

---

## Server-side reads (RSC + middleware)

`getStoredToken()` returns `null` on the server — `localStorage` doesn't exist. For server components that need the user, two patterns:

**1. Cookie mirror (recommended for protected RSCs).** Set a `pc-auth-<appId>-token` HTTP-only cookie from your sign-in flow's `Set-Cookie`, then read it in `cookies()` server-side.

**2. Client-only auth gate.** Keep authenticated pages as client components and let `useAuth().isLoading + token` drive the gate. Simpler; fits most admin / dashboard apps.

The SDK doesn't pick a side because the right answer depends on your SEO + auth-page-strategy tradeoffs.

---

## API verification (your backend)

The platform JWT is RS256-signed by the gateway. Your brand backend verifies it locally via JWKS — no client SDK needed there. Hono example:

```ts
import { jwt } from "hono/jwt";

app.use("/api/*", jwt({
  jwksUri: "https://auth.pixelcrafts.app/.well-known/jwks.json",
  alg: "RS256",
}));
```

NestJS uses `JwtAuthGuard` against the same JWKS endpoint. See [`../../docs/AUTH_INTEGRATION_GUIDE.md`](../../docs/AUTH_INTEGRATION_GUIDE.md) for both.

---

## Custom role mapping

By default the SDK route handler returns `role: "admin"` when the JWT's `entitlements` claim contains `"admin"`, else `"user"`. Override:

```ts
export const { POST } = createAuthRoute({
  appId: process.env.PIXELCRAFTS_APP_ID!,
  deriveRole: (claims) => {
    const ents = claims.entitlements as string[] | undefined;
    if (ents?.includes("super_admin")) return "super_admin";
    if (ents?.includes("billing_admin")) return "billing_admin";
    if (ents?.includes("admin")) return "admin";
    return "user";
  },
});
```

The shape returned to the client is always `{ token, user: { id, email, role, provider } }` — your `deriveRole` only changes which string lands in `role`.

---

## Migration from per-app auth

If your app currently has its own `lib/auth-service.ts` + `lib/auth-context.tsx` + `app/api/auth/verify/route.ts` (the lavamgam-web pattern), this SDK is a drop-in replacement:

| File | Before | After |
|---|---|---|
| `lib/auth-service.ts` | ~70 lines, per-app keys | **Delete.** SDK owns it. |
| `lib/auth-context.tsx` | ~80 lines, per-app key strings | **Delete.** `AuthProvider` + `useAuth` from SDK. |
| `app/api/auth/verify/route.ts` | ~100 lines, hardcoded `APP_ID` | **6 lines.** `createAuthRoute` factory. |
| Imports | `@/lib/auth-context` | `@pixelcrafts/auth` |

One PR per consumer — see [`../../docs/AUTH_INTEGRATION_GUIDE.md`](../../docs/AUTH_INTEGRATION_GUIDE.md).

---

## Build

```sh
pnpm install
pnpm build       # tsup → dist/{index,server}.{js,cjs,d.ts}
pnpm typecheck   # tsc --noEmit
```

The published artifact is `dist/`; `src/` and `example/` are excluded via `.npmignore`.

---

## What this SDK is NOT

- **Not a UI library.** No sign-in forms, no shadcn snippets. Your app keeps its own components.
- **Not a Firebase wrapper.** You call `signInWithEmailAndPassword`, `signInWithPopup`, etc. directly. The SDK only handles what comes *after* — the gateway exchange.
- **Not a state-management opinion.** Plain React Context. Wrap with Zustand / Jotai / Redux yourself if you want.
- **Not a payment SDK.** Separate package (`@pixelcrafts/payments`) when needed.

---

## License

MIT. See [LICENSE](../LICENSE).
