/// Thrown by sign-in / sign-up methods when the Firebase or social flow
/// fails. The [cancelled] flag distinguishes user-cancel (don't show an
/// error toast) from real failures (show an actionable message).
///
/// For 401s from the platform API (gateway / brand backends), use
/// [PCAuthException] — different layer, different remediation.
class PCSignInException implements Exception {
  const PCSignInException(this.message, {this.cancelled = false});

  final String message;

  /// True if the user explicitly cancelled (e.g., dismissed the Google
  /// sheet). UI should silently return to the previous state.
  final bool cancelled;

  @override
  String toString() => message;
}

/// Thrown when a request that requires authentication fails because the
/// platform JWT is missing, expired, or rejected. Distinct from
/// [PCSignInException] — this signals "your session is gone," not "your
/// sign-in attempt failed."
///
/// The Dio interceptor raises this after exhausting its single refresh
/// attempt. Consumers wire [PCAuth.onSessionExpired] to route to login.
class PCAuthException implements Exception {
  const PCAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
