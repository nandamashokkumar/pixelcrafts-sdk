/// Lifecycle states the SDK exposes via [PCAuth.authStateChanges].
///
/// - [initial]          — SDK is restoring tokens from storage; UI should
///                        show a splash, not redirect anywhere yet.
/// - [authenticated]    — token present, user object cached. APIs are
///                        callable.
/// - [unauthenticated]  — no token (clean state OR forced sign-out after
///                        a refresh-failure 401). UI should route to login.
///
/// The state is observable via [PCAuth.authStateChanges] (broadcast
/// stream). Synchronous reads via [PCAuth.currentState].
enum PCAuthState {
  initial,
  authenticated,
  unauthenticated,
}
