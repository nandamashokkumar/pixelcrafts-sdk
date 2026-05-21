/// pixelcrafts_auth — client SDK for the pixelcrafts central auth gateway.
///
/// Public API:
/// - [PCAuth] — the main entry. Singleton-per-config. Sign-in / sign-up /
///   sign-out / forgot-password / current-token + current-user.
/// - [PCUser] — typed user model.
/// - [PCAuthConfig] — per-app config (gateway URL + app ID).
/// - [PCAuthState] — auth lifecycle state enum.
/// - [PCAuthInterceptor] — Dio interceptor consumers attach to their
///   API client to get Bearer + x-user-id + single-flight 401 refresh.
/// - [PCSignInException] — typed error surface for sign-in failures.
/// - [SecureTokenStore] — exposed for advanced consumers; most apps
///   should not touch it directly.
///
/// Internals (in [src]) are not part of the public API and may change
/// in minor versions.
library;

export 'src/pc_auth.dart' show PCAuth;
export 'src/auth_state.dart' show PCAuthState;
export 'src/exceptions.dart' show PCSignInException, PCAuthException;
export 'src/models/pc_user.dart' show PCUser;
export 'src/models/pc_auth_config.dart' show PCAuthConfig;
export 'src/http/pc_auth_interceptor.dart' show PCAuthInterceptor;
export 'src/storage/secure_token_store.dart' show SecureTokenStore;
