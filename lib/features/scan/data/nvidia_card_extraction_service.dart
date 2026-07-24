import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';
import 'field_cleaners.dart';
import 'image_bytes.dart';

/// AI-powered business-card extraction using NVIDIA NIM's vision-language
/// models (OpenAI-compatible endpoint). Reads AND understands the card —
/// handling angles, logos, worn print and mixed layouts — far better than
/// raw OCR. Free tier: sign up at build.nvidia.com for an `nvapi-...` key.
///
/// Falls back to [fallback] when no key is set or the call fails.
class NvidiaCardExtractionService implements CardExtractionService {
  const NvidiaCardExtractionService(this.fallback);

  final CardExtractionService fallback;

  static const _endpoint =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  /// Vision-language model with strong document/image understanding.
  static const _model = 'meta/llama-3.2-90b-vision-instruct';

  static const _prompt = '''
Read this business card image and extract the contact details.
Return ONLY a JSON object (no markdown, no explanation) with exactly these keys:
{"full_name":"","first_name":"","designation":"","company_name":"","email":"","phone":"","alt_phone":"","website":"","address":"","city":"","state":"","postal_code":"","country":""}
Rules:
- Use "" for anything not visible on the card.
- Person's name and company name are different — don't confuse them.
- Keep phone numbers exactly as written (keep +, digits, spaces, hyphens).
- Do not guess or invent values. Only use what's visibly printed.
- Split addresses: "address" is ONLY the street/locality part; city,
  state, postal_code and country each go in their own fields. Never emit
  trailing commas.
- first_name = the first word of full_name.
''';

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    if (!AppConfig.hasNvidia) return fallback.extract(imagePath);

    try {
      final b64 = await imageToBase64(imagePath);
      if (b64 == null || b64.isEmpty) return fallback.extract(imagePath);

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64'}
              },
            ],
          }
        ],
        'temperature': 0,
        'max_tokens': 512,
        'stream': false,
      });

      final resp = await http
          .post(Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer ${AppConfig.nvidiaApiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode != 200) return fallback.extract(imagePath);

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = _firstContent(decoded);
      if (text == null) return fallback.extract(imagePath);

      final json = _parseJson(text);
      if (json == null) return fallback.extract(imagePath);

      final card = _fromJson(json);
      if (card.confidence == 0) return fallback.extract(imagePath);
      return Ok(card);
    } catch (_) {
      return fallback.extract(imagePath);
    }
  }

  String? _firstContent(Map<String, dynamic> decoded) {
    try {
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices.first['message'] as Map<String, dynamic>?;
      return message?['content'] as String?;
    } catch (_) {
      return null;
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
      firstName: FieldCleaners.text(raw('first_name')),
      designation: FieldCleaners.titleCase(raw('designation')),
      companyName: company,
      email: email,
      phone: phone,
      altPhone: FieldCleaners.text(raw('alt_phone')),
      website: FieldCleaners.text(raw('website'))?.toLowerCase(),
      address: FieldCleaners.address(raw('address')),
      city: FieldCleaners.titleCase(raw('city')),
      state: FieldCleaners.titleCase(raw('state')),
      postalCode: FieldCleaners.text(raw('postal_code')),
      country: FieldCleaners.titleCase(raw('country')),
      confidence: filled / 4.0,
    );
  }
}
