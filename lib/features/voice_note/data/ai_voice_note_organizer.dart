import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../actions/domain/pending_action.dart';
import '../../leads/domain/lead.dart';

/// Structured update derived from a voice note transcript.
/// Every field is optional; only the ones the AI could confidently extract
/// are populated. Callers merge these into the existing lead.
class VoiceNoteUpdate {
  const VoiceNoteUpdate({
    this.temperature,
    this.timeline,
    this.customerType,
    this.isDecisionMaker,
    this.exportRequirement,
    this.salesTeamRequired,
    this.summary,
    this.actions = const [],
  });

  final LeadTemperature? temperature;
  final RequirementTimeline? timeline;
  final CustomerType? customerType;
  final bool? isDecisionMaker;
  final bool? exportRequirement;
  final bool? salesTeamRequired;

  /// Clean, one-paragraph summary of everything else the user said that
  /// doesn't fit a structured field. Appended to the lead's notes.
  final String? summary;

  /// Action items the speaker asked to happen next — "call him Tuesday",
  /// "send WhatsApp with the catalog", etc. Each becomes a row in
  /// `pending_actions` that later drives reminders + automation.
  final List<PendingActionDraft> actions;

  bool get isEmpty =>
      temperature == null &&
      timeline == null &&
      customerType == null &&
      isDecisionMaker == null &&
      exportRequirement == null &&
      salesTeamRequired == null &&
      (summary == null || summary!.trim().isEmpty) &&
      actions.isEmpty;
}

/// Turn a raw voice-note transcript into structured qualification fields
/// plus a clean summary paragraph. Prefers Groq (llama-3.3-70b, generous
/// free tier); falls back to Gemini if only that key is set.
abstract final class AiVoiceNoteOrganizer {
  static const _groqModel = 'llama-3.3-70b-versatile';
  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _geminiModel = 'gemini-2.0-flash';
  static const _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _prompt = '''
You are given a raw transcript of a salesperson's verbal note about a
business lead they just met (e.g. at an exhibition). The transcript may
be in English, Hindi (written in Roman script — Hinglish), or a mix.

Your job:
1) Extract structured qualification signals when the speaker mentions them.
2) Write a clean, factual one-paragraph summary of everything else worth
   remembering (product interest, order size, budget, decision path,
   personal rapport notes, next-step commitments, etc.). Keep the summary
   in ENGLISH (translate any Hindi/Hinglish parts). No opinions, no fluff.
3) Extract EVERY "next action" the speaker committed to or asked for.
   Anything of the form "call him Tuesday", "send email with catalog",
   "WhatsApp the price list", "book a demo next week", "SMS the address"
   becomes one action item with a KIND, a short DESCRIPTION, and — if
   the speaker mentioned a time — a due date/time.

Return ONLY minified JSON with these exact keys:
{
  "temperature": "hot" | "warm" | "cold" | "",
  "timeline": "immediate" | "1-3 months" | "3-6 months" | "exploring" | "",
  "customer_type": "end user" | "distributor" | "retailer" | "oem" | "consultant" | "other" | "",
  "is_decision_maker": true | false | null,
  "export_requirement": true | false | null,
  "sales_team_required": true | false | null,
  "summary": "clean english paragraph, or empty string if speaker said nothing to remember",
  "actions": [
    {
      "kind": "call" | "email" | "whatsapp" | "sms" | "meeting" | "other",
      "description": "short imperative phrase — 'Send catalog PDF', 'Call and confirm sample dispatch'",
      "due_hint": "free-text time hint from the transcript, e.g. 'tomorrow', 'next Tuesday 3pm', or empty string if none"
    }
  ]
}

Rules:
- Use "" (empty string) or null when the speaker did NOT mention that field.
- Do NOT invent or guess. If the speaker said nothing about calling, the
  actions array must NOT contain a call item.
- "Hot" = ready to buy soon. "Warm" = interested. "Cold" = long-shot.
- The summary is the ONLY place free-form notes go — never repeat the
  structured fields or actions inside it.
- Kind mapping: "phone/call/ring" → call, "mail/email" → email,
  "WhatsApp/WA/whatsup" → whatsapp, "text/SMS" → sms, "meet/demo/visit"
  → meeting. Anything else → other.
''';

  /// Returns null when no AI key is configured or all attempts fail.
  /// Callers should show an error and let the user retry, keeping the raw
  /// transcript so nothing is lost.
  static Future<VoiceNoteUpdate?> organize(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;

    Map<String, dynamic>? json;
    if (AppConfig.hasGroq) json = await _callGroq(trimmed);
    if (json == null && AppConfig.hasGemini) json = await _callGemini(trimmed);
    if (json == null) return null;

    return VoiceNoteUpdate(
      temperature: _temperature(json['temperature']),
      timeline: _timeline(json['timeline']),
      customerType: _customerType(json['customer_type']),
      isDecisionMaker: _bool(json['is_decision_maker']),
      exportRequirement: _bool(json['export_requirement']),
      salesTeamRequired: _bool(json['sales_team_required']),
      summary: _nullable(json['summary']),
      actions: _actions(json['actions']),
    );
  }

  static List<PendingActionDraft> _actions(Object? raw) {
    if (raw is! List) return const [];
    final out = <PendingActionDraft>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final desc = _nullable(e['description']);
      if (desc == null) continue;
      final kind = _actionKind(e['kind']);
      final dueHint = _nullable(e['due_hint']);
      out.add(PendingActionDraft(
        kind: kind,
        description: desc,
        dueHint: dueHint,
      ));
    }
    return out;
  }

  static PendingActionKind _actionKind(Object? v) {
    switch (v?.toString().toLowerCase().trim()) {
      case 'call': return PendingActionKind.call;
      case 'email': return PendingActionKind.email;
      case 'whatsapp': return PendingActionKind.whatsapp;
      case 'sms': return PendingActionKind.sms;
      case 'meeting': return PendingActionKind.meeting;
    }
    return PendingActionKind.other;
  }

  static Future<Map<String, dynamic>?> _callGroq(String transcript) async {
    try {
      final body = jsonEncode({
        'model': _groqModel,
        'temperature': 0,
        'max_tokens': 700,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _prompt},
          {'role': 'user', 'content': 'TRANSCRIPT:\n$transcript'},
        ],
      });
      final resp = await http
          .post(Uri.parse(_groqEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              },
              body: body)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final choices = decoded['choices'] as List<dynamic>?;
      final content = choices?.first['message']?['content'] as String?;
      if (content == null) return null;
      return _parseJson(content);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _callGemini(String transcript) async {
    try {
      final uri = Uri.parse(
          '$_geminiEndpoint/$_geminiModel:generateContent?key=${AppConfig.geminiApiKey}');
      final body = jsonEncode({
        'contents': [
          {'parts': [
            {'text': _prompt},
            {'text': 'TRANSCRIPT:\n$transcript'},
          ]}
        ],
        'generationConfig': {
          'temperature': 0,
          'response_mime_type': 'application/json',
          'maxOutputTokens': 600,
        },
      });
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final content = candidates?.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts?.first['text'] as String?;
      if (text == null) return null;
      return _parseJson(text);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final s = text.indexOf('{');
      final e = text.lastIndexOf('}');
      if (s < 0 || e < 0 || e <= s) return null;
      try {
        return jsonDecode(text.substring(s, e + 1)) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  static String? _nullable(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool? _bool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == 'yes') return true;
    if (s == 'false' || s == 'no') return false;
    return null;
  }

  static LeadTemperature? _temperature(Object? v) {
    switch (v?.toString().toLowerCase().trim()) {
      case 'hot': return LeadTemperature.hot;
      case 'warm': return LeadTemperature.warm;
      case 'cold': return LeadTemperature.cold;
    }
    return null;
  }

  static RequirementTimeline? _timeline(Object? v) {
    final s = v?.toString().toLowerCase().trim();
    if (s == null || s.isEmpty) return null;
    if (s == 'immediate') return RequirementTimeline.immediate;
    if (s.contains('1') && s.contains('3')) return RequirementTimeline.oneToThreeMonths;
    if (s.contains('3') && s.contains('6')) return RequirementTimeline.threeToSixMonths;
    if (s.contains('explor')) return RequirementTimeline.exploring;
    return null;
  }

  static CustomerType? _customerType(Object? v) {
    switch (v?.toString().toLowerCase().trim()) {
      case 'end user':
      case 'enduser': return CustomerType.endUser;
      case 'distributor': return CustomerType.distributor;
      case 'retailer': return CustomerType.retailer;
      case 'oem': return CustomerType.oem;
      case 'consultant': return CustomerType.consultant;
      case 'other': return CustomerType.other;
    }
    return null;
  }
}
