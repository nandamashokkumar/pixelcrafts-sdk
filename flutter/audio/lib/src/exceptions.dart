/// Typed errors surfaced by `pixelcrafts_audio`. Keep this small and
/// consumer-facing — every exception thrown by the SDK should be one of
/// these (or a wrapped form). Lets UI code branch on cause without
/// scraping error message text.
sealed class PCAudioException implements Exception {
  final String message;
  const PCAudioException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// User denied microphone permission (or the OS denied it, e.g. iOS
/// privacy lock).
class PCMicPermissionDeniedException extends PCAudioException {
  const PCMicPermissionDeniedException()
      : super('Microphone permission was denied.');
}

/// The configured `tokenProvider` returned null — typically means the
/// user is signed out by the time the upload fires.
class PCNotAuthenticatedException extends PCAudioException {
  const PCNotAuthenticatedException()
      : super('No auth token available for upload.');
}

/// The upload itself failed (network, 4xx, 5xx). [statusCode] is the
/// HTTP status when the request reached the server; 0 when it didn't
/// (offline, DNS, etc.).
class PCUploadException extends PCAudioException {
  final int statusCode;
  final String? serverDetail;
  const PCUploadException(super.message, this.statusCode, [this.serverDetail]);
}

/// The recording finished but produced no audible audio — empty
/// transcript, zero amplitude, or the recorder returned no file.
class PCNoAudioCapturedException extends PCAudioException {
  const PCNoAudioCapturedException()
      : super('Recording produced no audible audio.');
}
