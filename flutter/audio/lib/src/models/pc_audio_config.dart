/// Function the SDK calls to fetch the current auth Bearer token. We
/// take a function rather than a static string so the SDK picks up
/// token refreshes from the auth layer (typically `pixelcrafts_auth`'s
/// `PCAuth.instance.currentToken`).
///
/// Returning `null` means "the user is signed out" — the SDK throws
/// [PCNotAuthenticatedException] when this fires during an upload.
typedef PCAudioTokenProvider = Future<String?> Function();

/// One-shot SDK config. Wired at app startup. The audio SDK has no
/// opinion about *where* tokens come from — that's the consumer's
/// (typically `pixelcrafts_auth`) job.
class PCAudioConfig {
  /// Where the STT upload goes. Joined with each call's `uploadPath`.
  /// Typically `https://api.pixelcrafts.app/api/v1` for the central
  /// mobile API.
  final String apiBase;

  /// `x-app-id` header value. The mobile API uses this to route
  /// per-brand quotas / billing.
  final String appId;

  /// Returns the Bearer to attach to every multipart upload. Wire to
  /// `pixelcrafts_auth`'s `PCAuth.instance.currentToken`-style getter.
  final PCAudioTokenProvider tokenProvider;

  /// BCP-47 locale tag passed alongside the audio for STT
  /// language-hinting. Defaults to `en-IN` (Indian English) since
  /// pixelcrafts is India-primary today. Per-call override is supported.
  final String defaultLocale;

  /// Network timeout for the upload call. STT can take a few seconds
  /// for long answers — 60s is generous enough not to false-cancel.
  final Duration uploadTimeout;

  const PCAudioConfig({
    required this.apiBase,
    required this.appId,
    required this.tokenProvider,
    this.defaultLocale = 'en-IN',
    this.uploadTimeout = const Duration(seconds: 60),
  });
}
