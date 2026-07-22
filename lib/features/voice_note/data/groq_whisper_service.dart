import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'audio_bytes.dart';

/// Speech-to-text using Groq's hosted Whisper large-v3.
///
/// Free tier at time of writing: ~14k requests/day, ~28800 seconds of audio
/// per day. Signup at <https://console.groq.com/keys> — email only, no card.
///
/// Model: `whisper-large-v3` — SOTA multilingual, auto-detects language
/// (English + Hindi + Hinglish all handled by one model, no toggle needed).
abstract final class GroqWhisperService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _model = 'whisper-large-v3';

  /// Returns null when the key isn't set, the audio can't be read, or the
  /// upstream call fails. Callers should surface an error and let the user
  /// retry (keep the local recording for a manual retry).
  ///
  /// [pathOrUrl] is whatever `AudioRecorder.stop()` returned — a file path
  /// on mobile, a `blob:` URL on web.
  /// [languageHint] is optional ISO-639-1 code ("en", "hi"). Leave null to
  /// let Whisper auto-detect (usually the right call).
  static Future<String?> transcribe(
    String pathOrUrl, {
    String? languageHint,
  }) async {
    if (!AppConfig.hasGroq) return null;

    final bytes = await readAudioBytes(pathOrUrl);
    if (bytes == null || bytes.isEmpty) return null;
    // Groq's audio upload limit is 25 MB. Cap here so we return a clean
    // error instead of a 413.
    if (bytes.length > 24 * 1024 * 1024) return null;

    try {
      // Filename extension tells Groq/Whisper the container format.
      // record 5.x writes m4a on Android/iOS/desktop and webm/opus on Chrome.
      final filename = _guessFilename(bytes);

      final req = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer ${AppConfig.groqApiKey}'
        ..fields['model'] = _model
        ..fields['response_format'] = 'json'
        ..fields['temperature'] = '0'
        // Domain prompt biases Whisper away from generic YouTube-ending
        // hallucinations like "Thank you." / "Thanks for watching" when
        // audio is short, quiet, or noisy. Also gives it context that the
        // speaker may mix English and Hindi (Hinglish, Roman script).
        ..fields['prompt'] = _biasPrompt;
      if (languageHint != null) req.fields['language'] = languageHint;
      req.files.add(http.MultipartFile.fromBytes(
        'file', bytes,
        filename: filename,
      ));

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final text = (decoded['text'] ?? '').toString().trim();
      if (text.isEmpty) return null;
      // Whisper hallucinates a small set of stock phrases when it can't
      // find real speech (too short, mostly silence, format mismatch).
      // Reject those so callers show a proper retry error, not garbage.
      if (_looksLikeHallucination(text)) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  /// Domain prompt fed to Whisper as an "initial prompt" — steers decoding
  /// toward business dictation and away from generic hallucinations. Kept
  /// short intentionally (Whisper's prompt window is ~224 tokens).
  static const _biasPrompt =
      'Sales dictation about a business lead met at a trade show. '
      'Contains proper names, company names, product requirements, order '
      'quantities, budgets, timelines, and follow-up steps. Speech may '
      'switch between English and Hindi (Hindi transliterated in Roman '
      'script, e.g. "namaste bhaiya kaise ho").';

  static bool _looksLikeHallucination(String s) {
    final t = s.toLowerCase().trim().replaceAll(RegExp(r'[.!?,"\s]+$'), '');
    const stock = {
      'thank you', 'thanks for watching', 'thanks',
      'thank you for watching', 'please subscribe',
      'like and subscribe', 'thank you very much',
      'thanks for listening', 'bye bye', 'bye',
      'you', '.', '. .', 'okay', 'ok',
    };
    return stock.contains(t);
  }

  /// Pick a filename with the correct extension by sniffing the container.
  static String _guessFilename(List<int> b) {
    if (b.length >= 4 &&
        b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'voice-note.webm';
    }
    if (b.length >= 8 &&
        b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return 'voice-note.m4a';
    }
    if (b.length >= 4 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46) {
      return 'voice-note.wav';
    }
    if (b.length >= 4 &&
        b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67 && b[3] == 0x53) {
      return 'voice-note.ogg';
    }
    return 'voice-note.m4a';
  }
}
