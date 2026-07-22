import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'ai_card_organizer.dart';
import 'parsers/business_card_parser.dart';

/// Tier-0 extractor on mobile: Google ML Kit text recognition, on-device.
///
/// Free, no key, no network, no rate limit. Uses the phone's built-in
/// ML runtime — Apple's Vision on iOS, ML Kit on Android. Accuracy is
/// state-of-the-art on printed text (matches or beats server OCR).
///
/// Returns per-line bounding boxes → [BusinessCardParser] uses layout to
/// split name / company / designation / address deterministically.
///
/// This service is a **no-op on web and desktop** (see the stub in
/// `ml_kit_extraction_service_stub.dart` — Dart's conditional export picks
/// the right file at compile time so the mobile-only package never leaks
/// into a web build).
class MlKitExtractionService implements CardExtractionService {
  const MlKitExtractionService(this.fallback);

  final CardExtractionService fallback;

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    // On desktop platforms (Windows / macOS / Linux) the package's native
    // code is not available; defer to the fallback.
    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return fallback.extract(imagePath);
    }

    TextRecognizer? recognizer;
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return fallback.extract(imagePath);

      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);

      final lines = <OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isEmpty) continue;
          final r = line.boundingBox;
          lines.add(OcrLine(
            text: t,
            x: r.left.toDouble(),
            y: r.top.toDouble(),
            w: r.width.toDouble(),
            h: r.height.toDouble(),
            confidence: 1.0, // ML Kit doesn't expose a per-line score
          ));
        }
      }

      if (lines.isEmpty) return fallback.extract(imagePath);

      // If a Gemini key is set, prefer the AI organizer — same reasoning
      // as OcrSpaceExtractionService: it handles OCR mangling better than
      // pure regex, and the text-only call is fast + cheap.
      final aiCard = await AiCardOrganizer.organize(lines);
      if (aiCard != null && aiCard.confidence > 0) return Ok(aiCard);

      final card = BusinessCardParser.parse(lines);
      if (card.confidence == 0) return fallback.extract(imagePath);
      return Ok(card);
    } catch (_) {
      return fallback.extract(imagePath);
    } finally {
      await recognizer?.close();
    }
  }
}
