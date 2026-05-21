# pixelcrafts_audio

Client SDK for the pixelcrafts audio + STT surface. Mic permission, recording (with optional auto-VAD), authenticated multipart upload to a transcription endpoint, transcript + cost return. **Extracted from mintly-app's `voice_service.dart`** — so every brand app inherits the same battle-tested audio plumbing instead of reinventing it.

Sibling to [`pixelcrafts_auth`](../auth) — wire them together: the auth SDK supplies the bearer; the audio SDK uses it on every upload.

## Install

```yaml
# your_app/pubspec.yaml
dependencies:
  pixelcrafts_audio:
    git:
      url: https://github.com/pixelcrafts-app/pixelcrafts-sdk
      path: flutter/audio
      ref: audio-flutter-v0.1.0
```

```sh
flutter pub get
```

The SDK declares `record`, `permission_handler`, `path_provider`, and `http` as deps. Consumers don't need to add them separately.

## Configure once

```dart
import 'package:pixelcrafts_audio/pixelcrafts_audio.dart';
import 'package:pixelcrafts_auth/pixelcrafts_auth.dart';

PCAudio.configure(PCAudioConfig(
  apiBase: 'https://api.pixelcrafts.app/api/v1',
  appId: 'interviewace',
  tokenProvider: () async => PCAuth.instance.currentToken,
  defaultLocale: 'en-IN',
));
```

The audio SDK doesn't import `pixelcrafts_auth` directly — it just calls the function you give it. Apps without `pixelcrafts_auth` (e.g. mintly's legacy API-key model) wire `tokenProvider` to whatever returns their token.

## Session API (full control)

```dart
final session = PCAudio.instance.openSession(
  uploadPath: '/learning/questions/q_42/practice-feedback',
  extraFields: {'questionId': 'q_42'},
);

await session.startRecording(autoVad: true);

// Auto-end of utterance via 1.2s silence-after-speech detection
session.autoEndDetected.listen((_) async {
  final turn = await session.stopAndSend();
  if (turn == null) return;
  print(turn.transcript);
  print(turn.extra['keyPointsHit']);
  await session.dispose();
});

// Or manual stop on a button tap:
//   final turn = await session.stopAndSend();
//   await session.dispose();
//
// Or cancel without uploading:
//   await session.stopAndDiscard();
//   await session.dispose();
```

## Convenience API (record-once)

For UIs that don't need to expose recording state — fire-and-await:

```dart
final turn = await PCAudio.instance.recordOnce(
  uploadPath: '/learning/questions/q_42/practice-feedback',
  maxDuration: const Duration(seconds: 60),
);
print(turn.transcript);
```

Auto-VAD by default; falls through to `maxDuration` if the user doesn't pause.

## VoiceTurn shape

```dart
class VoiceTurn {
  String transcript;             // what the user said
  double? confidence;            // 0..1 if upstream STT provides it
  int costCents;                 // server-reported cost for billing UI
  Duration recordingDuration;    // wall-clock recording length
  String? providerRequestId;     // upstream provider correlation id
  Map<String, dynamic> extra;    // per-app extra fields (scoring, etc.)
}
```

`extra` is the escape hatch for app-specific server data. The SDK doesn't interpret it; the consumer reads keys it knows about.

## Errors

```dart
sealed class PCAudioException {}
class PCMicPermissionDeniedException
class PCNotAuthenticatedException
class PCUploadException { int statusCode; String? serverDetail; }
class PCNoAudioCapturedException
```

`sealed` so a `switch` over the type exhausts cleanly.

## What this SDK does NOT do

- **UI** — no waveform widget, no record button, no layout. Bring your own.
- **Scoring** — the SDK uploads audio and returns whatever JSON the server sent back. Comparing transcript to an expected answer is the consumer / backend's job.
- **TTS** — playback of generated speech isn't here yet. If a brand needs it, a separate `pixelcrafts_audio_tts` (or a method on this SDK) is the v0.2 conversation.
- **Realtime / full-duplex WebSocket STT** — mintly's `realtime_mode_screen.dart` does this directly today; not extracted here because it's a different protocol (provider-direct WS, not gateway-mediated multipart). Could land as `PCAudio.openRealtimeSession(...)` later.

## Where the upload goes

Pointed at whatever endpoint the consumer hands in. Typically:

| App | Endpoint | Contract |
|---|---|---|
| interviewace | `/learning/questions/:id/practice-feedback` | `{ transcript, keyPointsHit[], antiPatternsTriggered[], scorePct }` |
| mintly | `/voice/sessions/:sid/user-turn` | `{ transcript, costCents }` |
| (future brands) | their own | as long as it returns `{ transcript: string, ... }` |

The endpoint is what differs per app; the recording + upload plumbing doesn't.

## License

MIT — internal, pixelcrafts apps only.
