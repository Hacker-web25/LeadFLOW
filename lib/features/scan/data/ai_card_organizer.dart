import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/card_extraction_service.dart';
import 'field_cleaners.dart';
import 'parsers/business_card_parser.dart';

/// Text-only AI post-processor for OCR output.
///
/// Takes raw OCR lines (from OCR.space, ML Kit, or any other extractor)
/// and asks a large language model to organize them into structured card
/// fields. This layer fixes:
///   - Glued words ("SourabhTiwari" → "Sourabh Tiwari")
///   - Field misclassification (address landing in company slot)
///   - Broken emails ("sourabh @ site.com" → "sourabh@site.com")
///   - Context understanding (a title next to a name vs company suffix)
///
/// It uses **text-only** completion — no image is sent. Fast (~500ms) and
/// cheap. Prefers Groq (llama-3.3-70b, generous free tier) and falls back
/// to Gemini if only that key is set.
///
/// Returns null when no AI key is configured or all attempts fail;
/// callers should fall back to [BusinessCardParser] in that case.
abstract final class AiCardOrganizer {
  // Groq: OpenAI-compatible chat endpoint. llama-3.3-70b-versatile is the
  // best free-tier text model — very good structured JSON, 30 req/min.
  static const _groqModel = 'llama-3.3-70b-versatile';
  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  // Gemini kept as fallback for when Groq is missing / rate limited.
  static const _geminiModel = 'gemini-2.0-flash';
  static const _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _prompt = '''
You are given raw OCR output from a business card, one detected line per row.
Your job is to organize this into clean, structured contact fields.

Rules:
- Return ONLY valid minified JSON. No markdown fences, no commentary.
- Use empty string "" for any field not present on the card.
- Do NOT invent, guess, or hallucinate values. Only use what's in the OCR.
- Fix obvious OCR concatenations like "SourabhTiwari" → "Sourabh Tiwari",
  "ZonalHead" → "Zonal Head", "IEast" → "I East".
- Fix broken emails like "sourabh . tiwari @ site . com" → "sourabh.tiwari@site.com".
- The person's NAME and the COMPANY NAME are different things. Do not confuse them.
- ADDRESS goes in the address field, NEVER in company. Address is usually
  a comma-separated string with a street/sector/plot and a postal code.
- WEBSITE is a standalone domain like "www.example.com", NOT the domain part
  of an email address.
- Keep phone numbers exactly as written (preserve +, digits, spaces, hyphens).
- If two phone numbers are present, put the first in "phone" and second in "alt_phone".
- Extract CITY and COUNTRY from the address if identifiable. City is a
  proper city name (not "Sector-80" or "Plot-42").

- Split addresses: the "address" field is ONLY the street/locality
  ("901, The Summit Business Bay, Off Andheri-Kurla Road, Andheri East");
  city, state, postal_code and country each get their own fields. Do NOT
  emit trailing or double commas anywhere.
- first_name is just the first token of full_name (e.g. "Sumesh").

Required JSON shape (exact keys, all strings):
{"full_name":"","first_name":"","designation":"","company_name":"","email":"","phone":"","alt_phone":"","website":"","address":"","city":"","state":"","postal_code":"","country":""}
''';

  /// Returns null when no AI key is configured, the call fails, or the
  /// model refuses. Callers should fall back to the rule-based parser.
  static Future<ExtractedCard?> organize(List<OcrLine> lines) async {
    if (lines.isEmpty) return null;

    // Feed lines to the model one per row, prefixed by index — helps the
    // model reason about layout order without needing coordinates.
    final ocrText = [
      for (var i = 0; i < lines.length; i++) '${i + 1}. ${lines[i].text}',
    ].join('\n');

    // Prefer Groq (bigger free tier). Fall back to Gemini on any failure
    // so a temporary Groq outage still yields a good result.
    if (AppConfig.hasGroq) {
      final r = await _callGroq(ocrText);
      if (r != null) return r;
    }
    if (AppConfig.hasGemini) {
      final r = await _callGemini(ocrText);
      if (r != null) return r;
    }
    return null;
  }

  static Future<ExtractedCard?> _callGroq(String ocrText) async {
    try {
      final body = jsonEncode({
        'model': _groqModel,
        'temperature': 0,
        'max_tokens': 500,
        // JSON mode: Groq forces a valid JSON object out.
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _prompt},
          {'role': 'user', 'content': 'OCR OUTPUT:\n$ocrText'},
        ],
      });
      final resp = await http
          .post(Uri.parse(_groqEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final choices = decoded['choices'] as List<dynamic>?;
      final content = choices?.first['message']?['content'] as String?;
      if (content == null) return null;
      final json = _parseJson(content);
      return json == null ? null : _fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<ExtractedCard?> _callGemini(String ocrText) async {
    try {
      final uri = Uri.parse(
          '$_geminiEndpoint/$_geminiModel:generateContent?key=${AppConfig.geminiApiKey}');
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': _prompt},
              {'text': 'OCR OUTPUT:\n$ocrText'},
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0,
          'response_mime_type': 'application/json',
          'maxOutputTokens': 400,
        },
      });
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final content = candidates?.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts?.first['text'] as String?;
      if (text == null) return null;
      final json = _parseJson(text);
      return json == null ? null : _fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseJson(String text) {
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

  static ExtractedCard _fromJson(Map<String, dynamic> j) {
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
