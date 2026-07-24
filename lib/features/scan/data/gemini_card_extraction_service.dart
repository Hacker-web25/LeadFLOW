import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'field_cleaners.dart';
import 'image_bytes.dart';

/// AI-powered business-card extraction using Google Gemini vision.
///
/// Sends the card image to Gemini with a strict JSON schema and parses the
/// structured response. This reads *and understands* the card (handles
/// angles, logos, worn text, mixed layouts) far more reliably than raw OCR.
///
/// Falls back to [fallback] (on-device OCR) when no API key is configured
/// or the network call fails.
class GeminiCardExtractionService implements CardExtractionService {
  const GeminiCardExtractionService(this.fallback);

  final CardExtractionService fallback;

  static const _model = 'gemini-2.0-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _prompt = '''
You are extracting contact details from a photograph of a business card.
Read ALL text on the card carefully, including small print and text next to icons.
Return ONLY a JSON object (no markdown, no commentary) with EXACTLY these keys:
{
  "full_name": string,        // the person's name (not the company)
  "designation": string,      // job title / role
  "company_name": string,     // the company or organisation
  "email": string,            // primary email address
  "phone": string,            // primary mobile/phone number with country code if shown
  "alt_phone": string,        // a second phone number if present, else ""
  "website": string,          // website/domain, without http://
  "address": string,          // full street address on one line
  "city": string,             // city only
  "country": string           // country only
}
Rules:
- If a field is not present on the card, use an empty string "".
- Keep phone numbers exactly as written (keep +, digits, spaces, hyphens).
- Do NOT invent or guess values. Only use what is visibly on the card.
- The person's name and the company name are different things — do not confuse them.
''';

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    if (!AppConfig.hasGemini) return fallback.extract(imagePath);

    try {
      final b64 = await imageToBase64(imagePath);
      if (b64 == null || b64.isEmpty) return fallback.extract(imagePath);

      final uri = Uri.parse(
          '$_endpoint/$_model:generateContent?key=${AppConfig.geminiApiKey}');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': b64}
              },
              {'text': _prompt},
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0,
          'response_mime_type': 'application/json',
        },
      });

      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        // Auth/quota/etc — fall back rather than failing the whole scan.
        return fallback.extract(imagePath);
      }

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = _firstText(decoded);
      if (text == null) return fallback.extract(imagePath);

      final json = _parseJson(text);
      if (json == null) return fallback.extract(imagePath);

      final card = _fromJson(json);
      // If Gemini genuinely found nothing, let the fallback try.
      if (card.confidence == 0) return fallback.extract(imagePath);
      return Ok(card);
    } catch (_) {
      return fallback.extract(imagePath);
    }
  }

  String? _firstText(Map<String, dynamic> decoded) {
    try {
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      return parts.first['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Strip ```json fences or stray prose, then retry on the {...} slice.
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      try {
        return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  ExtractedCard _fromJson(Map<String, dynamic> j) {
    String? raw(String k) => j[k]?.toString();

    final name = FieldCleaners.text(raw('full_name'));
    final company = FieldCleaners.text(raw('company_name'));
    final email = FieldCleaners.text(raw('email'))?.toLowerCase();
    final phone = FieldCleaners.text(raw('phone'));

    final filled = [name, company, email, phone]
        .where((v) => v != null && v.isNotEmpty)
        .length;

    return ExtractedCard(
      fullName: name,
      designation: FieldCleaners.titleCase(raw('designation')),
      companyName: company,
      email: email,
      phone: phone,
      altPhone: FieldCleaners.text(raw('alt_phone')),
      website: FieldCleaners.text(raw('website'))?.toLowerCase(),
      address: FieldCleaners.address(raw('address')),
      city: FieldCleaners.titleCase(raw('city')),
      country: FieldCleaners.titleCase(raw('country')),
      confidence: filled / 4.0,
    );
  }
}
