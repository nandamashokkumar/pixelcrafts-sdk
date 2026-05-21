import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'exceptions.dart';
import 'models/pc_audio_config.dart';
import 'models/voice_turn.dart';

/// Top-level entry. One-time `PCAudio.configure(...)` at app startup,
/// then `PCAudio.instance.openSession(...)` per recording.
///
/// Sessions, not a single global recorder, because the per-session
/// state (start time, last-speech-at, auto-end stream) is easier to
/// reason about as its own object — and a few apps do want to record
/// multiple short clips in parallel.
class PCAudio {
  PCAudio._();

  static PCAudio? _instance;
  static PCAudioConfig? _config;

  static void configure(PCAudioConfig config) {
    _config = config;
    _instance = PCAudio._();
  }

  static PCAudio get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'PCAudio.configure(...) must be called before PCAudio.instance. '
        'Wire it once at app startup, typically in main().',
      );
    }
    return i;
  }

  /// Reserved for tests — wipe the singleton so a second `configure`
  /// call takes effect.
  static void resetForTesting() {
    _instance = null;
    _config = null;
  }

  /// Open a fresh recording session pointed at a given upload endpoint.
  ///
  /// [uploadPath] is appended to `PCAudioConfig.apiBase`. The endpoint
  /// must accept a multipart POST with a part named `audio` and return
  /// JSON containing at minimum a `transcript` field. Per-app scoring
  /// data (key-points-hit, anti-patterns, etc.) is welcome in any
  /// other fields — surfaced as [VoiceTurn.extra].
  RecordingSession openSession({
    required String uploadPath,
    String? locale,
    Map<String, String>? extraFields,
  }) {
    final config = _config!;
    return RecordingSession._(
      config: config,
      uploadPath: uploadPath,
      locale: locale ?? config.defaultLocale,
      extraFields: extraFields ?? const {},
    );
  }

  /// Convenience: record-once → wait for auto-VAD end-of-utterance →
  /// upload → return the turn. Closes the session afterwards. For UIs
  /// that don't need to expose the recording state stream.
  Future<VoiceTurn> recordOnce({
    required String uploadPath,
    String? locale,
    Map<String, String>? extraFields,
    bool autoVad = true,
    Duration maxDuration = const Duration(seconds: 30),
  }) async {
    final session = openSession(
      uploadPath: uploadPath,
      locale: locale,
      extraFields: extraFields,
    );
    try {
      await session.startRecording(autoVad: autoVad);
      if (autoVad) {
        await session.autoEndDetected.first.timeout(maxDuration,
            onTimeout: () {});
      } else {
        await Future<void>.delayed(maxDuration);
      }
      final turn = await session.stopAndSend();
      if (turn == null) throw const PCNoAudioCapturedException();
      return turn;
    } finally {
      await session.dispose();
    }
  }
}

/// One recording lifecycle. Construct via `PCAudio.instance.openSession`,
/// dispose when done.
class RecordingSession {
  final PCAudioConfig _config;
  final String _uploadPath;
  final String _locale;
  final Map<String, String> _extraFields;

  final AudioRecorder _recorder = AudioRecorder();
  final _autoEndController = StreamController<void>.broadcast();

  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _recordStartedAt;
  DateTime? _lastSpeechAt;
  bool _hasSpoken = false;
  bool _recording = false;
  bool _disposed = false;

  /// Above this dB threshold counts as speech. dB scale is negative
  /// (-60 = silence floor, 0 = peak); -40 is the mintly-tuned cutoff.
  static const double _speechDb = -40;

  /// Silence window after first speech that triggers auto-end.
  static const Duration _silenceWindow = Duration(milliseconds: 1200);

  /// Grace period before VAD starts firing — stops auto-end from
  /// triggering before the user has had a chance to start talking.
  static const Duration _minRecordBeforeAutoStop =
      Duration(milliseconds: 600);

  RecordingSession._({
    required PCAudioConfig config,
    required String uploadPath,
    required String locale,
    required Map<String, String> extraFields,
  })  : _config = config,
        _uploadPath = uploadPath,
        _locale = locale,
        _extraFields = extraFields;

  /// Fires when auto-VAD detects ~1.2s of silence after at least one
  /// speech sample. Subscribers should call [stopAndSend].
  Stream<void> get autoEndDetected => _autoEndController.stream;

  /// True between [startRecording] and [stopAndSend] / [stopAndDiscard].
  bool get isRecording => _recording;

  /// Start capturing audio. Requests mic permission if needed.
  /// Throws [PCMicPermissionDeniedException] if denied.
  Future<void> startRecording({bool autoVad = true}) async {
    _ensureLive();
    if (_recording) return;

    if (!await _ensureMicPermission()) {
      throw const PCMicPermissionDeniedException();
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/pcaudio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _recordStartedAt = DateTime.now();
    _lastSpeechAt = null;
    _hasSpoken = false;
    _recording = true;

    if (autoVad) _startAmplitudeMonitor();
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    return (await Permission.microphone.request()).isGranted;
  }

  void _startAmplitudeMonitor() {
    _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen(_onAmplitude);
  }

  void _onAmplitude(Amplitude amp) {
    if (!_recording) return;
    final now = DateTime.now();
    final started = _recordStartedAt;
    if (started != null &&
        now.difference(started) < _minRecordBeforeAutoStop) {
      return;
    }
    if (amp.current > _speechDb) {
      _hasSpoken = true;
      _lastSpeechAt = now;
      return;
    }
    final last = _lastSpeechAt;
    if (!_hasSpoken || last == null) return;
    if (now.difference(last) >= _silenceWindow) {
      // Fire once per session; consumer decides whether to act.
      _autoEndController.add(null);
      _ampSub?.cancel();
      _ampSub = null;
    }
  }

  /// Stop recording, upload the captured audio, return the parsed turn.
  /// Throws on permission, network, or server errors. Returns null if
  /// the recording produced no audio (empty file).
  Future<VoiceTurn?> stopAndSend() async {
    _ensureLive();
    if (!_recording) return null;
    _stopAmplitudeMonitor();

    final filePath = await _recorder.stop();
    final endedAt = DateTime.now();
    final duration = _recordStartedAt == null
        ? Duration.zero
        : endedAt.difference(_recordStartedAt!);
    _recording = false;

    if (filePath == null) return null;

    final file = File(filePath);
    if (!await file.exists() || (await file.length()) == 0) {
      _deleteSilently(file);
      return null;
    }

    try {
      final token = await _config.tokenProvider();
      if (token == null) throw const PCNotAuthenticatedException();

      final uri = Uri.parse('${_config.apiBase}$_uploadPath');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'x-app-id': _config.appId,
        })
        ..fields['locale'] = _locale
        ..fields.addAll(_extraFields)
        ..files.add(await http.MultipartFile.fromPath(
          'audio',
          filePath,
          filename: 'recording.m4a',
        ));

      final streamed =
          await request.send().timeout(_config.uploadTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 400) {
        throw PCUploadException(
          'Upload failed',
          response.statusCode,
          response.body.isEmpty ? null : response.body,
        );
      }

      final json = _safeDecode(response.body);
      return VoiceTurn(
        transcript: json['transcript'] as String? ?? '',
        confidence: _asDouble(json['confidence']),
        costCents: (json['costCents'] as num? ?? 0).toInt(),
        recordingDuration: duration,
        providerRequestId: json['providerRequestId'] as String?,
        extra: Map<String, dynamic>.from(json)
          ..removeWhere((k, _) => const {
                'transcript',
                'confidence',
                'costCents',
                'providerRequestId',
              }.contains(k)),
      );
    } finally {
      _deleteSilently(file);
    }
  }

  /// Stop recording without uploading and return the captured audio
  /// file. The caller becomes responsible for deleting [filePath] after
  /// consuming. Used by apps whose upload boundary differs from the SDK
  /// default (different endpoint shape, non-Bearer auth, session-scoped
  /// upload) — they still benefit from PCAudio's recording + VAD.
  ///
  /// Returns `null` if the recording produced no audio (empty file).
  Future<({String filePath, Duration duration})?> stopAndCapture() async {
    _ensureLive();
    if (!_recording) return null;
    _stopAmplitudeMonitor();

    final filePath = await _recorder.stop();
    final endedAt = DateTime.now();
    final duration = _recordStartedAt == null
        ? Duration.zero
        : endedAt.difference(_recordStartedAt!);
    _recording = false;

    if (filePath == null) return null;
    final file = File(filePath);
    if (!await file.exists() || (await file.length()) == 0) {
      _deleteSilently(file);
      return null;
    }
    return (filePath: filePath, duration: duration);
  }

  /// Stop recording without uploading. Used for cancel paths.
  Future<void> stopAndDiscard() async {
    _ensureLive();
    if (!_recording) return;
    _stopAmplitudeMonitor();
    final path = await _recorder.stop();
    _recording = false;
    if (path != null) _deleteSilently(File(path));
  }

  void _stopAmplitudeMonitor() {
    _ampSub?.cancel();
    _ampSub = null;
    _recordStartedAt = null;
    _lastSpeechAt = null;
    _hasSpoken = false;
  }

  /// Tear down the recorder + amplitude stream. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopAmplitudeMonitor();
    if (_recording) {
      // Best-effort — don't throw from dispose.
      try {
        final path = await _recorder.stop();
        if (path != null) _deleteSilently(File(path));
      } catch (_) {
        // ignore
      }
    }
    await _recorder.dispose();
    await _autoEndController.close();
  }

  void _ensureLive() {
    if (_disposed) {
      throw StateError(
        'RecordingSession was disposed; open a new one via '
        'PCAudio.instance.openSession(...).',
      );
    }
  }

  void _deleteSilently(File f) {
    // Fire-and-forget. Temp file cleanup is best-effort; the OS will
    // reclaim the cache directory under pressure anyway.
    f.delete().catchError((_) => f);
  }

  static Map<String, dynamic> _safeDecode(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'transcript': body};
    } catch (_) {
      return {'transcript': body};
    }
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
