import 'lead.dart';

/// Deterministic heuristic for "this scan probably needs a human sanity check".
///
/// Kept intentionally simple — the point is to surface the obviously
/// suspicious ones (missing key fields, mangled OCR patterns) so the rep
/// can focus review time there, not to catch every possible problem.
abstract final class NeedsReview {
  /// True when the lead has at least one strong signal that a field is
  /// wrong, missing, or mangled.
  static bool check(Lead lead) {
    final c = lead.contact;
    final company = lead.company;

    // 1) Missing both an email AND a phone → no way to follow up.
    final noEmail = (c.email ?? '').trim().isEmpty;
    final noPhone = (c.phone ?? '').trim().isEmpty && (c.altPhone ?? '').trim().isEmpty;
    if (noEmail && noPhone) return true;

    // 2) Missing name or empty company (both should almost always be present).
    if (c.fullName.trim().isEmpty) return true;
    if (company == null || company.name.trim().isEmpty) return true;

    // 3) Name looks OCR-mangled.
    if (_looksMangled(c.fullName)) return true;

    // 4) Company looks OCR-mangled or too long (marketing tagline slipped in).
    if (_looksMangled(company.name)) return true;
    if (company.name.length > 60) return true;

    // 5) Email doesn't have @ (broken OCR) OR domain looks off.
    final email = c.email;
    if (email != null && email.isNotEmpty && !email.contains('@')) return true;

    // 6) Phone has < 7 digits (surely misread).
    for (final p in [c.phone, c.altPhone]) {
      if (p == null || p.isEmpty) continue;
      final digits = p.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7) return true;
    }

    return false;
  }

  static bool _looksMangled(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;
    // Digits inside what should be a name / company.
    if (RegExp(r'\d').hasMatch(t) && t.length < 8) return true;
    // Camel-case glued words like "SourabhTiwari" or "ZonalHead".
    // A capital letter directly following a lowercase letter, at least twice.
    final glueMatches = RegExp(r'[a-z][A-Z]').allMatches(t).length;
    if (glueMatches >= 1 && !t.contains(' ')) return true;
    // Ends with a colon or pipe (leftover section header).
    if (t.endsWith(':') || t.endsWith('|')) return true;
    // Contains @ or / (URL/email crumb).
    if (t.contains('@') || t.contains('://')) return true;
    return false;
  }
}
