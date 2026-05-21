/// Result of one record → upload → transcribe cycle.
///
/// `transcript` is the canonical surface — every UI flow that uses the
/// SDK reads this. Everything else is supporting metadata for the
/// consumer's own analytics / billing display.
class VoiceTurn {
  /// What the user said, as transcribed by the upstream STT model.
  final String transcript;

  /// Confidence reported by the STT model, 0.0..1.0. Null when the
  /// provider doesn't return a per-utterance confidence.
  final double? confidence;

  /// Server-reported cost for the transcription call, in cents. Used by
  /// consumer UI for "free generations remaining" banners.
  final int costCents;

  /// Wall-clock duration of the recording, end-to-end (start to stop).
  final Duration recordingDuration;

  /// Server-side correlation id from the underlying AI provider (e.g.
  /// OpenAI's `whisper-1` request id). Useful for diagnosing failed
  /// transcriptions with the team.
  final String? providerRequestId;

  /// Arbitrary extra fields the server endpoint returned alongside the
  /// transcript — e.g. per-app scoring data like `keyPointsHit`,
  /// `antiPatternsTriggered`, `scorePct`. The SDK doesn't interpret
  /// these; the consumer parses them as needed.
  final Map<String, dynamic> extra;

  const VoiceTurn({
    required this.transcript,
    required this.recordingDuration,
    this.confidence,
    this.costCents = 0,
    this.providerRequestId,
    this.extra = const {},
  });
}
