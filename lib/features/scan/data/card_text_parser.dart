import '../domain/card_extraction_service.dart';

/// Best-effort parser turning raw OCR text into a structured [ExtractedCard].
/// Deliberately conservative — a wrong guess is worse than an empty field,
/// because the user must confirm every field on the review screen anyway.
abstract final class CardTextParser {
  static final _emailRe = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  static final _urlRe = RegExp(
      r'(?:https?://)?(?:www\.)?[A-Za-z0-9-]+\.[A-Za-z]{2,}(?:/[^\s]*)?',
      caseSensitive: false);
  static final _phoneRe = RegExp(r'(?:\+?\d[\d\s\-().]{7,}\d)');

  static const _designationHints = [
    'ceo', 'cto', 'cfo', 'coo', 'vp', 'president', 'director', 'head',
    'manager', 'lead', 'sourcing', 'procurement', 'sales', 'marketing',
    'engineer', 'consultant', 'founder', 'partner', 'owner', 'purchase',
    'buyer', 'account', 'business', 'operations', 'proprietor',
  ];
  static const _companyHints = [
    'inc', 'llc', 'ltd', 'limited', 'corp', 'corporation', 'co.',
    'gmbh', 'pvt', 'private', 'plc', 'company', 'group', 'industries',
    'enterprises', 'solutions', 'systems', 'technologies', 'services',
    'international', 'holdings', 'trading', 'exports', 'imports',
    'associates', 'partners',
  ];

  static ExtractedCard parse(String rawText) {
    final raw = rawText.replaceAll('\r', '');
    if (raw.trim().isEmpty) {
      return const ExtractedCard(confidence: 0);
    }

    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final joined = lines.join(' ');

    // Structured fields via regex over the full text (safer than line-based).
    final email = _emailRe.firstMatch(joined)?.group(0);
    final website = _pickWebsite(joined, email);
    final phones = _phoneRe
        .allMatches(joined)
        .map((m) => m.group(0)!.trim())
        .where((p) => p.replaceAll(RegExp(r'\D'), '').length >= 7)
        .toList();

    // Attempt to identify company vs person name from the remaining lines.
    final structuralLines = lines.where((l) {
      final low = l.toLowerCase();
      return !_emailRe.hasMatch(l) &&
          !_phoneRe.hasMatch(l) &&
          !low.contains('@') &&
          !low.contains('www.') &&
          !low.contains('.com') &&
          !low.contains('.in') &&
          !low.contains('.co') &&
          !low.contains('.org') &&
          !low.contains('.net');
    }).toList();

    String? company;
    String? designation;
    String? name;

    for (final l in structuralLines) {
      final low = l.toLowerCase();
      if (company == null && _companyHints.any(low.contains)) {
        company = _titleCase(l);
        continue;
      }
      if (designation == null && _designationHints.any(low.contains)) {
        designation = _titleCase(l);
        continue;
      }
    }

    // Pick a plausible name: 2–4 mostly-alphabetic words that look like a
    // person's name (not the same as company/designation).
    for (final l in structuralLines) {
      final tokens = l.split(RegExp(r'\s+'));
      if (tokens.length < 2 || tokens.length > 5) continue;
      final looksLikeName = tokens.every((t) =>
          RegExp(r"^[A-Za-z][A-Za-z'.-]{0,}$").hasMatch(t));
      if (!looksLikeName) continue;
      final candidate = _titleCase(l);
      if (candidate.toLowerCase() == (company ?? '').toLowerCase()) continue;
      if (candidate.toLowerCase() == (designation ?? '').toLowerCase()) continue;
      name = candidate;
      break;
    }

    // Address heuristic: line containing digits + comma or 5+ words.
    String? address;
    for (final l in structuralLines) {
      final commaHeavy = l.contains(',') &&
          RegExp(r'\d').hasMatch(l);
      if (commaHeavy || l.split(' ').length >= 5) {
        address = l;
        break;
      }
    }

    // City / country: last comma-separated tokens of the address.
    String? city, country;
    if (address != null) {
      final parts = address.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        country = _titleCase(parts.last);
        city = _titleCase(parts[parts.length - 2]);
      }
    }

    // Confidence = fraction of fields we filled.
    final filled = [name, company, email, phones.isNotEmpty ? phones.first : null]
        .where((v) => v != null && v.trim().isNotEmpty)
        .length;
    final confidence = filled / 4.0;

    return ExtractedCard(
      fullName: name,
      designation: designation,
      companyName: company,
      email: email,
      phone: phones.isNotEmpty ? phones.first : null,
      website: website,
      address: address,
      city: city,
      country: country,
      confidence: confidence,
    );
  }

  static String? _pickWebsite(String text, String? excludeEmail) {
    for (final m in _urlRe.allMatches(text)) {
      final url = m.group(0)!;
      if (excludeEmail != null && excludeEmail.contains(url)) continue;
      if (url.contains('@')) continue;
      return url.replaceFirst(RegExp(r'^https?://'), '');
    }
    return null;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty
          ? w
          : (w.length == 1 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1).toLowerCase()))
      .join(' ');
}
