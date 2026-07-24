import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'field_cleaners.dart';
import 'image_bytes.dart';

/// AI-powered business-card extraction using **Groq vision**.
///
/// Groq's Llama-4 Scout multimodal model has industry-leading vision-token
/// throughput (typically 300+ ms end-to-end) and, on its free tier, is
/// generous enough for exhibition-day scanning. Because the model reads
/// the actual image (not raw OCR text) it handles small print, angled
/// shots, coloured backgrounds and stacked layouts far better than any
/// classic OCR + parser combo — the "double comma / cut-off address"
/// bugs go away because there's no downstream text reconstruction step.
///
/// Falls back to [fallback] (the rest of the chain) when the key is
/// missing or the call fails, so this tier is always a strict upgrade.
class GroqVisionExtractionService implements CardExtractionService {
  const GroqVisionExtractionService(this.fallback);

  final CardExtractionService fallback;

  // Groq's Llama-4 Scout is their fastest vision model with a 128k context
  // window — plenty for a card photo + structured JSON reply.
  static const _model = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const _prompt = '''
You are extracting contact details from a photograph of a business card.
Read EVERY piece of text on the card carefully, including small print,
text next to icons, addresses in the footer, and country codes.

Return ONLY a JSON object (no markdown, no commentary) with EXACTLY these keys:
{
  "full_name": string,        // person's name (never the company)
  "designation": string,      // job title / role
  "company_name": string,     // company or organisation
  "email": string,            // primary email address, lowercased
  "phone": string,            // primary mobile/phone number with country code if shown
  "alt_phone": string,        // second phone number if present, else ""
  "website": string,          // website/domain, without http://, without www.
  "address": string,          // full street address on ONE line, comma-separated
  "city": string,             // city only, no state, no postal code
  "country": string           // country only
}

Rules:
- If a field is not on the card, use empty string "".
- NEVER invent or guess. Only use what is visibly printed.
- Person's name and company name are different — do not confuse them.
- Keep phone numbers exactly as printed (preserve +, digits, spaces, hyphens).
- Address: DO NOT emit trailing or double commas. If a component is
  missing, just leave it out.
- City must be a real city name (not "Sector 80" or "Plot 42").
- Website should not include the email domain if only an email is shown.
''';

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    if (!AppConfig.hasGroq) return fallback.extract(imagePath);

    try {
      final b64 = await imageToBase64(imagePath);
      if (b64 == null || b64.isEmpty) return fallback.extract(imagePath);

      final body = jsonEncode({
        'model': _model,
        'temperature': 0,
        'max_tokens': 700,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$b64',
                }
              },
            ],
          },
        ],
      });

      final resp = await http
          .post(Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200) return fallback.extract(imagePath);

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return fallback.extract(imagePath);
      final choices = decoded['choices'] as List<dynamic>?;
      final content = choices?.first['message']?['content'] as String?;
      if (content == null) return fallback.extract(imagePath);

      final json = _parseJson(content);
      if (json == null) return fallback.extract(imagePath);

      final card = _fromJson(json);
      if (card.confidence == 0) return fallback.extract(imagePath);
      return Ok(card);
    } catch (_) {
      return fallback.extract(imagePath);
    }
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      try {
        return jsonDecode(text.substring(start, end + 1))
            as Map<String, dynamic>;
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
