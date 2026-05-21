# Changelog

All notable changes are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/). Versions follow [SemVer](https://semver.org/).

Each package SemVers independently. Tags shaped `<package>-vX.Y.Z` (e.g., `auth-flutter-v0.1.0`, `audio-flutter-v0.1.0`, `auth-web-v0.1.0`).

---

## Repo — 2026-05-19

### Restructured into a multi-package monorepo

Renamed `pixelcrafts-auth-sdk` → `pixelcrafts-sdk`. Moved each package under a per-language / per-name subfolder so additional SDKs can live alongside auth:

```
pixelcrafts-sdk/
  flutter/auth/     ← was: pixelcrafts-auth-sdk/flutter
  flutter/audio/    ← new (extracted from mintly's voice_service)
  web/auth/         ← was: pixelcrafts-auth-sdk/web
  docs/AUTH_INTEGRATION_GUIDE.md   ← renamed from INTEGRATION_GUIDE.md
```

Consumer impact:
- Flutter: `path: flutter` → `path: flutter/auth`, git URL becomes `pixelcrafts-sdk`
- Web: file-link path becomes `pixelcrafts-sdk/web/auth`; npm package name unchanged

Existing Firebase aliases (`exchangeFirebaseToken`, `firebaseSignOut`) still work.

---

## [audio-flutter-v0.1.0] — 2026-05-19

Initial extraction from `mintly-app/lib/core/services/voice_service.dart`.

### Added — `pixelcrafts_audio` (Flutter / Dart)

- `PCAudio.configure(PCAudioConfig)` — one-time bootstrap at app start
- `PCAudio.instance.openSession(uploadPath, ...)` — fresh recording session
- `PCAudio.instance.recordOnce(uploadPath, ...)` — convenience method for fire-and-await UIs
- `RecordingSession`:
  - `startRecording(autoVad: bool)` — captures via `record` package; m4a/AAC-LC/16kHz/mono
  - `autoEndDetected` stream — fires after ~1.2s silence-after-speech (mintly-tuned)
  - `stopAndSend()` — uploads multipart to consumer-supplied endpoint, returns `VoiceTurn`
  - `stopAndDiscard()` — cancel path
  - `dispose()` — idempotent teardown
- `VoiceTurn { transcript, confidence, costCents, recordingDuration, providerRequestId, extra }`
- `PCAudioTokenProvider` callback so the SDK doesn't statically depend on `pixelcrafts_auth`
- Sealed exception hierarchy: `PCMicPermissionDeniedException`, `PCNotAuthenticatedException`, `PCUploadException`, `PCNoAudioCapturedException`
- Framework deps: `record`, `permission_handler`, `path_provider`, `http`. No `dio` (avoids transitive dep clashes with consumers that pin a different dio major).

### Out of scope (deliberately deferred)

- UI (waveform widget, record button, layout)
- Server-side scoring (`extra` field surfaces app-specific data, but comparison-to-expected-answer is consumer/backend's job)
- TTS playback — separate SDK or v0.2 method when a brand needs it
- Realtime / full-duplex WS STT (mintly's `realtime_mode_screen.dart` does this directly; could land as `openRealtimeSession` later)

---

## [auth-flutter-v0.1.0 / auth-web-v0.1.0] — 2026-05-19

Initial extraction from `lavamgam-app` + `lavamgam-web` — both in production with the gateway-exchange auth flow verified end-to-end.

### Added — `pixelcrafts_auth` (Flutter / Dart)

- `PCAuth` class with configurable singleton:
  - `signInWithEmail(email, password)`
  - `signUpWithEmail(email, password)`
  - `signInWithGoogle()`
  - `signInWithApple()`
  - `signInWithTwitter()`
  - `sendPasswordResetEmail(email)`
  - `signOut()`
  - `currentToken`, `currentUser`, `authStateChanges` stream
- `PCUser` model — id, email, role, provider, displayName, photoUrl
- `PCAuthConfig` — gatewayUrl + appId per-app pinning
- `SecureTokenStore` — wraps `flutter_secure_storage` with encrypted preferences on Android, keychain on iOS
- `PCAuthInterceptor` (Dio) — Bearer + x-user-id + single-flight 401 refresh + onSessionExpired callback
- `SignInException` typed errors with `cancelled` flag for user-cancel cases
- Zero opinion on state management — consumers wire into Riverpod / Bloc / Provider as they prefer
- Framework deps: `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `dio`, `flutter_secure_storage`, `shared_preferences`

### Added — `@pixelcrafts/auth` (TypeScript / Web)

- `PCAuth` class — same surface as the Flutter package, adapted for the browser:
  - `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signInWithApple`, `signInWithTwitter`
  - `sendPasswordResetEmail`, `signOut`
  - `currentToken`, `currentUser`, `onAuthStateChange` callback
- `createAuthVerifyRoute(config)` — Next.js App Router route factory that handles the server-side `/auth/token` exchange. Drop-in for `app/api/auth/verify/route.ts`.
- `AuthProvider` + `useAuth()` React Context hook
- `storeAuth`, `getStoredToken`, `getStoredUser`, `clearAuth` — direct localStorage helpers (for non-React consumers)
- Cross-tab sync via `storage` events
- Framework deps: `firebase` (peer), `react` (peer, optional)

### Out of scope (deliberately deferred)

- Payments — will live in `pixelcrafts-payments-sdk` when needed
- UI components — apps own their sign-in screens
- Analytics / crash reporting
