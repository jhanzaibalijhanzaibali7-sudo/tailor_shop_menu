import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result of one listening session.
class VoiceResult {
  /// Best transcript first, followed by the engine's alternatives.
  final List<String> transcripts;

  /// Set when nothing usable was heard (permission denied, no speech, ...).
  final String? error;

  const VoiceResult(this.transcripts, [this.error]);

  bool get ok => transcripts.isNotEmpty;
  bool get permissionDenied =>
      error != null && error!.toLowerCase().contains('permission');
}

/// Thin wrapper around speech_to_text: one call = one spoken command.
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _sawListening = false;
  String? _lastError;
  Completer<void>? _done;
  final Map<String, String?> _localeCache = {};

  bool get isListening => _speech.isListening;

  Future<bool> _ensureReady() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          _lastError = e.errorMsg;
          final d = _done;
          if (d != null && !d.isCompleted) d.complete();
        },
        onStatus: (status) {
          if (status == 'listening') _sawListening = true;
          final d = _done;
          if (d == null || d.isCompleted) return;
          if (_sawListening && (status == 'notListening' || status == 'done')) {
            d.complete();
          }
        },
      );
    } catch (e) {
      _ready = false;
      _lastError = e.toString();
    }
    return _ready;
  }

  /// Picks the recognition locale. [pref] is one of auto, sd, ur, hi, en.
  /// Sindhi speech recognition is not installed on every phone, so the lists
  /// fall back to Urdu / Hindi / English, which still produce text the parser
  /// understands.
  Future<String?> _localeIdFor(String pref) async {
    if (_localeCache.containsKey(pref)) return _localeCache[pref];
    List<stt.LocaleName> all;
    try {
      all = await _speech.locales();
    } catch (_) {
      return null;
    }
    String norm(String id) => id.replaceAll('-', '_').toLowerCase();
    String? find(List<String> prefixes) {
      for (final prefix in prefixes) {
        for (final l in all) {
          if (norm(l.localeId).startsWith(prefix)) return l.localeId;
        }
      }
      return null;
    }

    String? id;
    switch (pref) {
      case 'sd':
        id = find(['sd_pk', 'sd', 'ur_pk', 'ur', 'en_in', 'en_us', 'en']);
        break;
      case 'ur':
        id = find(['ur_pk', 'ur', 'en_in', 'en_us', 'en']);
        break;
      case 'hi':
        id = find(['hi_in', 'hi', 'en_in', 'en_us', 'en']);
        break;
      case 'en':
        id = find(['en_in', 'en_us', 'en_gb', 'en']);
        break;
      default:
        id = find(['sd_pk', 'sd', 'ur_pk', 'ur', 'en_in', 'en_us', 'en']);
    }
    _localeCache[pref] = id;
    return id;
  }

  List<String> _collect(SpeechRecognitionResult r) {
    final out = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    add(r.recognizedWords);
    for (final alt in r.alternates) {
      add(alt.recognizedWords);
    }
    return out;
  }

  /// Listens until the user stops talking (or [listenFor] runs out).
  Future<VoiceResult> listenOnce({
    required String localePref,
    void Function(String partial)? onPartial,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    _lastError = null;
    if (!await _ensureReady()) {
      return VoiceResult(const [], _lastError ?? 'permission or service unavailable');
    }
    final localeId = await _localeIdFor(localePref);

    final done = Completer<void>();
    _done = done;
    _sawListening = false;
    var transcripts = <String>[];
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) {
          transcripts = _collect(r);
          onPartial?.call(r.recognizedWords);
          if (r.finalResult && !done.isCompleted) done.complete();
        },
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
      );
      await done.future
          .timeout(listenFor + const Duration(seconds: 4), onTimeout: () {});
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _done = null;
    }

    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
    // The last result can arrive just after the engine stops.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (transcripts.isEmpty) {
      return VoiceResult(const [], _lastError ?? 'no_speech');
    }
    return VoiceResult(transcripts);
  }

  /// Ends the current session early; the words heard so far are still used.
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
