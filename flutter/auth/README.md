# pixelcrafts_auth (Flutter)

Client SDK for the **pixelcrafts central auth gateway** (`auth.pixelcrafts.app`). Drop-in replacement for per-app `auth_service.dart` boilerplate.

```dart
// app bootstrap
PCAuth.configure(const PCAuthConfig(appId: 'fluentpro'));

// sign in
final user = await PCAuth.instance.signInWithEmail('a@b.c', 'pw');

// attach the Bearer interceptor to your API Dio
final api = Dio(BaseOptions(baseUrl: 'https://api.pixelcrafts.app/api/v1'))
  ..interceptors.add(PCAuth.instance.interceptor);

// observe state
PCAuth.instance.authStateChanges.listen((state) {
  if (state == PCAuthState.unauthenticated) router.go('/login');
});
```

That's it. No `auth_service.dart`, no exchange logic, no token storage code, no refresh interceptor — the SDK owns all of it.

---

## Install

```yaml
# your_app/pubspec.yaml
dependencies:
  pixelcrafts_auth:
    git:
      url: https://github.com/pixelcrafts-app/pixelcrafts-sdk
      path: flutter/auth
      ref: auth-flutter-v0.1.0   # pin exact version
```

```
flutter pub get
```

The `path: flutter/auth` field tells `pub` to look inside the auth sub-package of the SDK monorepo. Other packages in the same repo: `pixelcrafts_audio` at `flutter/audio`, `@pixelcrafts/auth` (web) at `web/auth`.

### Prerequisites in the consumer app

1. **Firebase initialized.** The SDK does not initialize Firebase — your app does, with its own `firebase_options.dart`. Call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `main()` before anything else.
2. **Firebase project registered with the gateway.** The pcauth_db `apps` row for this `appId` must have `firebase_project_id` set to your Firebase project. Operators do this via `pixelcrafts-web-admin`.
3. **Sign in with Apple** capability enabled in Xcode (iOS). Required by App Store guideline 4.8 when offering Google or other social sign-in.

---

## Public API

### `PCAuth.configure(config)`

Call once during app startup, before the first `PCAuth.instance` access.

```dart
PCAuth.configure(const PCAuthConfig(
  appId: 'fluentpro',
  gatewayUrl: 'https://auth.pixelcrafts.app',  // default; override for local dev
));
```

### `PCAuth.instance`

The configured singleton. Throws `StateError` if `configure` wasn't called.

### Sign-in methods

All return `Future<PCUser>`. All throw `PCSignInException` on failure (with `.cancelled = true` for user-cancel cases).

```dart
await PCAuth.instance.signInWithEmail(email, password);
await PCAuth.instance.signUpWithEmail(email, password);
await PCAuth.instance.signInWithGoogle();
await PCAuth.instance.signInWithApple();
await PCAuth.instance.signInWithTwitter();
```

### Password reset

```dart
await PCAuth.instance.sendPasswordResetEmail(email);
```

Firebase handles delivery + the reset-flow link.

### Sign out

```dart
await PCAuth.instance.signOut();
```

Clears Firebase session, Google session, all SDK-managed secure storage, and flips state to `PCAuthState.unauthenticated`. Always completes — errors during Firebase signOut are swallowed because local state must always clear.

### Current state — synchronous

```dart
final token = PCAuth.instance.currentToken;        // String? (platform JWT)
final user = PCAuth.instance.currentUser;          // PCUser?
final state = PCAuth.instance.currentState;        // PCAuthState
```

### State stream

```dart
PCAuth.instance.authStateChanges.listen((state) {
  switch (state) {
    case PCAuthState.initial:         break;  // splash, no action
    case PCAuthState.authenticated:   router.go('/home');
    case PCAuthState.unauthenticated: router.go('/login');
  }
});
```

### Session-expired callback

Wired once during app startup, fires when the SDK detects an irrecoverable session (refresh failed after a 401). Local state is already cleared by the time this fires; you only need to route.

```dart
PCAuth.instance.onSessionExpired = () => router.go('/login');
```

### Interceptor

```dart
final api = Dio(BaseOptions(baseUrl: 'https://api.brand.com'))
  ..interceptors.add(PCAuth.instance.interceptor);
```

The interceptor:
- Injects `Authorization: Bearer <platform JWT>` + `x-app-id: <configured app id>` on every request.
- On a 401: refreshes the token (single-flight — concurrent 401s share one refresh), replays the original request transparently.
- If refresh fails: fires `onSessionExpired`, propagates the original error.

---

## State management — works with anything

The SDK is intentionally agnostic. Pick one:

### Riverpod

```dart
final authStateProvider = StreamProvider<PCAuthState>((ref) {
  return PCAuth.instance.authStateChanges;
});

final currentUserProvider = Provider<PCUser?>((ref) {
  ref.watch(authStateProvider);  // trigger rebuilds on state change
  return PCAuth.instance.currentUser;
});
```

### Bloc / Cubit

```dart
class AuthCubit extends Cubit<PCAuthState> {
  AuthCubit() : super(PCAuthState.initial) {
    PCAuth.instance.authStateChanges.listen(emit);
  }
}
```

### `setState` / Provider / GetX

Same pattern: subscribe to `authStateChanges`, read `currentUser` / `currentToken` synchronously.

The SDK never imports any of these — that's the consumer's choice.

---

## Multi-tenant — multiple apps in one process

Most consumers have one `PCAuth` per app. If you genuinely need multiple (e.g., a super-admin tool that switches between brand identities), construct a non-singleton instance manually:

```dart
final lavamgam = PCAuth.configure(const PCAuthConfig(appId: 'lavamgam'));
// later, with a different app id, use PCAuth.resetForTesting() then configure again.
// Multi-instance support is intentionally out-of-scope for v0.1 — singleton
// covers every real consumer today.
```

---

## Migration from the legacy auth pattern

If your app currently uses the **legacy `/auth/sync` path** (Firebase ID token sent directly to `api.pixelcrafts.app/api/v1/auth/sync`), this SDK replaces it:

| Before | After |
|---|---|
| Firebase login → backend `/auth/sync` with Firebase ID token | Firebase login → gateway `/auth/token` → platform JWT |
| Bearer = Firebase ID token | Bearer = platform JWT (RS256, JWKS-verified) |
| Backend re-validates Firebase token per request | Backend verifies JWT locally via cached JWKS — no per-call network |
| Per-app `auth_service.dart` (~250 lines) | `PCAuth.configure(...)` + 5 lines of UI wiring |

The migration is one PR per app — see [`../../docs/AUTH_INTEGRATION_GUIDE.md`](../../docs/AUTH_INTEGRATION_GUIDE.md).

---

## Versioning

SemVer + git-tag pinning. Pin the exact `ref` in `pubspec.yaml`; never use a branch. Breaking changes ship behind a major-version bump with a 90-day deprecation cycle.

---

## What this SDK is NOT

- Not a UI library. No sign-in screen, no buttons. Your app keeps its own design.
- Not a state-management opinion. Works with Riverpod / Bloc / Provider / GetX / setState equally well.
- Not a payment SDK. Will be `pixelcrafts_payments` (separate package) when needed.
- Not a backend SDK. Brand backends verify JWTs directly via `jose` (Hono) or `JwtAuthGuard` (NestJS) against the gateway's JWKS endpoint — no client SDK needed there.

---

## License

MIT. See [LICENSE](../LICENSE).
