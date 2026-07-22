import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'ai_card_organizer.dart';
import 'image_bytes.dart';
import 'parsers/business_card_parser.dart';

/// Tier-1 extractor: OCR.space free API (works on web + mobile + desktop).
///
/// Free tier: 500 requests/day, no credit card, just an email signup at
/// <https://ocr.space/ocrapi>. Engine 2 is the best-quality OCR they offer.
///
/// Returns per-word bounding boxes → [BusinessCardParser] uses geometry
/// (font size = line height, position) to split name / company /
/// designation / address without any LLM.
///
/// Falls back to [fallback] when no API key is set, quota is hit, or the
/// call fails / returns empty.
class OcrSpaceExtractionService implements CardExtractionService {
  const OcrSpaceExtractionService(this.fallback);

  final CardExtractionService fallback;

  static const _endpoint = 'https://api.ocr.space/parse/image';

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    final apiKey = AppConfig.ocrSpaceApiKey;
    if (apiKey.isEmpty) return fallback.extract(imagePath);

    try {
      final b64 = await imageToBase64(imagePath);
      if (b64 == null || b64.isEmpty) return fallback.extract(imagePath);

      // OCR.space accepts base64 as multipart/form-data field.
      // See https://ocr.space/OCRAPI for full param list.
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'apikey': apiKey,
        },
        body: {
          'base64Image': 'data:image/jpeg;base64,$b64',
          'language': 'eng',
          'isOverlayRequired': 'true', // returns per-word bounding boxes
          'OCREngine': '2', // best-quality engine, supports Latin scripts
          'scale': 'true', // upscale small images for better accuracy
          'detectOrientation': 'true', // auto-correct rotated cards
          'isTable': 'false',
        },
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return fallback.extract(imagePath);

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return fallback.extract(imagePath);

      // Error signalling: OCR.space uses IsErroredOnProcessing + ErrorMessage.
      if (decoded['IsErroredOnProcessing'] == true) {
        return fallback.extract(imagePath);
      }

      final parsedResults = decoded['ParsedResults'];
      if (parsedResults is! List || parsedResults.isEmpty) {
        return fallback.extract(imagePath);
      }

      final lines = _extractLines(parsedResults.first);
      if (lines.isEmpty) return fallback.extract(imagePath);

      // If a Gemini key is set, prefer the AI organizer — it handles
      // OCR mangling (glued words, broken emails, address in company) far
      // better than pure regex/heuristic rules. Text-only, ~500ms, cheap.
      final aiCard = await AiCardOrganizer.organize(lines);
      if (aiCard != null && aiCard.confidence > 0) return Ok(aiCard);

      final card = BusinessCardParser.parse(lines);
      if (card.confidence == 0) return fallback.extract(imagePath);
      return Ok(card);
    } catch (_) {
      return fallback.extract(imagePath);
    }
  }

  /// Convert OCR.space's overlay format into [OcrLine]s.
  ///
  /// OCR.space returns TextOverlay.Lines[i] with .Words[j] that each carry
  /// {WordText, Left, Top, Width, Height}. A "line" bounding box is the
  /// union of its words' boxes, and the "line text" is the joined words.
  static List<OcrLine> _extractLines(dynamic parsedResult) {
    if (parsedResult is! Map) return const [];

    final overlay = parsedResult['TextOverlay'];
    if (overlay is Map) {
      final overlayLines = overlay['Lines'];
      if (overlayLines is List && overlayLines.isNotEmpty) {
        final out = <OcrLine>[];
        for (final line in overlayLines) {
          if (line is! Map) continue;
          final words = line['Words'];
          if (words is! List || words.isEmpty) continue;

          double? minX, minY, maxX, maxY;
          final buf = StringBuffer();
          for (final w in words) {
            if (w is! Map) continue;
            final text = (w['WordText'] ?? '').toString();
            if (text.isEmpty) continue;
            if (buf.isNotEmpty) buf.write(' ');
            buf.write(text);
            final x = _asDouble(w['Left']);
            final y = _asDouble(w['Top']);
            final ww = _asDouble(w['Width']);
            final hh = _asDouble(w['Height']);
            minX = (minX == null || x < minX) ? x : minX;
            minY = (minY == null || y < minY) ? y : minY;
            maxX = (maxX == null || x + ww > maxX) ? x + ww : maxX;
            maxY = (maxY == null || y + hh > maxY) ? y + hh : maxY;
          }
          if (buf.isEmpty || minX == null) continue;
          out.add(OcrLine(
            text: buf.toString(),
            x: minX,
            y: minY!,
            w: maxX! - minX,
            h: maxY! - minY,
            confidence: 1.0, // OCR.space doesn't expose per-line confidence
          ));
        }
        if (out.isNotEmpty) return out;
      }
    }

    // Fallback: if overlay is empty for some reason, split ParsedText into
    // lines with synthetic (equal-height, sequential-Y) boxes so the
    // parser still has something ordered to work with.
    final parsedText = (parsedResult['ParsedText'] ?? '').toString();
    if (parsedText.trim().isEmpty) return const [];
    final rawLines = parsedText
        .replaceAll('\r', '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return [
      for (var i = 0; i < rawLines.length; i++)
        OcrLine(
          text: rawLines[i],
          x: 0,
          y: i * 30.0,
          w: rawLines[i].length * 8.0,
          h: 24,
          confidence: 1.0,
        ),
    ];
  }

  static double _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
