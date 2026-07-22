import 'package:flutter/foundation.dart';

import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'card_text_parser.dart';
import 'web_ocr.dart' as web_ocr;

/// Real OCR-backed extraction.
///
/// - Web: runs tesseract.js on the picked image (blob URL) via JS interop.
/// - Non-web: falls back to the stub for now (mobile ML Kit is the next
///   milestone; the interface won't change).
class TesseractCardExtractionService implements CardExtractionService {
  const TesseractCardExtractionService();

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    try {
      if (kIsWeb) {
        final text = await web_ocr.extractTextFromUrl(imagePath);
        if (text.trim().isEmpty) {
          return const Err(AppFailure(
              "Couldn't read this card. Try a sharper, well-lit photo."));
        }
        return Ok(CardTextParser.parse(text));
      }
      // Mobile/desktop: return an empty card so the user can fill it in.
      // A native OCR engine (ML Kit) drops in here without touching the UI.
      return const Ok(ExtractedCard(confidence: 0));
    } catch (e) {
      return Err(AppFailure('OCR failed. Please retake the photo.', cause: e));
    }
  }
}
