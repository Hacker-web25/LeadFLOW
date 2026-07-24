import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'ai_card_organizer.dart';
import 'image_bytes.dart';
import 'parsers/business_card_parser.dart';

/// Best-in-class OCR path — Google Cloud Vision reads the image, then
/// Groq's Llama-3.3-70B (via [AiCardOrganizer]) turns the raw text into
/// structured contact fields.
///
/// Why this combo:
///   - Google Cloud Vision is the highest-accuracy OCR on the market for
///     business cards (handles small print, foreign scripts, watermarks,
///     angled shots the best of any hosted OCR). Free tier: 1000 units
///     per month.
///   - Vision doesn't structure the output — it just returns text. So we
///     hand that text to the same organizer prompt we already use for
///     other OCR sources, which reliably splits it into name / email /
///     phone / address / etc.
///
/// Falls back to [fallback] (the rest of the chain) if the key is missing
/// or the call fails. Configure via
/// `--dart-define=GCV_API_KEY=AIza…`
class GoogleVisionExtractionService implements CardExtractionService {
  const GoogleVisionExtractionService(this.fallback);

  final CardExtractionService fallback;

  static const _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    if (!AppConfig.hasGoogleCloudVision) return fallback.extract(imagePath);

    try {
      final b64 = await imageToBase64(imagePath);
      if (b64 == null || b64.isEmpty) return fallback.extract(imagePath);

      // DOCUMENT_TEXT_DETECTION is optimised for dense text (business
      // cards, receipts, forms). Cheaper than TEXT_DETECTION and higher
      // accuracy for our use case.
      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': b64},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1}
            ],
            // English + common Latin languages; add "hi" etc. if needed.
            'imageContext': {
              'languageHints': ['en']
            }
          }
        ]
      });

      final uri = Uri.parse('$_endpoint?key=${AppConfig.googleCloudVisionKey}');
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return fallback.extract(imagePath);

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return fallback.extract(imagePath);
      final responses = decoded['responses'] as List<dynamic>?;
      if (responses == null || responses.isEmpty) {
        return fallback.extract(imagePath);
      }
      final first = responses.first as Map<String, dynamic>;

      // GCV returns everything in `fullTextAnnotation.text` (newline-
      // separated, layout-preserving). Perfect input for the organizer.
      final fullText =
          (first['fullTextAnnotation']?['text'] as String?) ?? '';
      if (fullText.trim().isEmpty) return fallback.extract(imagePath);

      // Feed each line as one OcrLine so the AI organizer can reason
      // about layout order (top-of-card usually = name/title).
      // OcrLine requires geometry — we don't feed it back to a layout-
      // aware parser here, only the AI organizer (which cares about text
      // order, not coordinates), so zeroed geometry is fine.
      final split = fullText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final lines = <OcrLine>[
        for (var i = 0; i < split.length; i++)
          OcrLine(
              text: split[i],
              x: 0, y: i.toDouble(), w: 0, h: 1, confidence: 1),
      ];

      final organised = await AiCardOrganizer.organize(lines);
      if (organised != null && organised.confidence > 0) return Ok(organised);

      return fallback.extract(imagePath);
    } catch (_) {
      return fallback.extract(imagePath);
    }
  }
}
