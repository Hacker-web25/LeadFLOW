import 'dart:math' as math;

import '../../domain/card_extraction_service.dart';

/// A single OCR-detected text line with its geometry and confidence.
/// Coordinates are pixels in the source image; origin is top-left.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
  });

  final String text;
  final double x;
  final double y;
  final double w;
  final double h;
  final double confidence;

  double get cy => y + h / 2;
  double get cx => x + w / 2;
}

/// Structured business-card parser.
///
/// Input: OCR lines + boxes (from PaddleOCR).
/// Output: [ExtractedCard] with all fields filled where possible.
///
/// Pure Dart, zero network calls, no LLM. Uses:
///   - regex for email / phone / URL / postal codes
///   - box geometry (height as font-size proxy, Y position as hierarchy)
///   - keyword dictionaries for designation / company / country
///
/// Every field is optional and reviewed by the user before save — but we
/// aim for as-close-to-zero manual edits as possible on typical cards.
abstract final class BusinessCardParser {
  // --- regex --------------------------------------------------------------

  static final _emailRe = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  /// Accept common web URL shapes: with or without scheme, with or without
  /// www., with common TLDs. Excludes email-embedded domains later.
  static final _urlRe = RegExp(
    r'(?:https?://)?(?:www\.)?[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+(?:/[^\s]*)?',
    caseSensitive: false,
  );

  /// Phone shape: optional +, 7+ digits total, allows spaces / dashes /
  /// parens / dots between digits. We validate digit count post-match.
  static final _phoneRe = RegExp(
    r'(?:\+?\d[\d\s().\-]{6,}\d)',
  );

  /// Common postal-code shapes for the top ~30 countries we expect to see
  /// on cards. If any of these match, the line is very likely address.
  static final _postalRe = RegExp(
    r'\b(?:\d{5}(?:-\d{4})?|[A-Z]\d[A-Z]\s?\d[A-Z]\d|[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}|\d{6}|\d{4}\s?[A-Z]{2}|\d{3}-?\d{4})\b',
    caseSensitive: false,
  );

  // --- dictionaries -------------------------------------------------------

  static const _titleKeywords = {
    // C-suite
    'ceo', 'cto', 'cfo', 'coo', 'cmo', 'cio', 'cpo', 'chro',
    'chief', 'president', 'vice president', 'vp', 'evp', 'svp',
    // director / head
    'director', 'managing director', 'md', 'head', 'head of',
    // manager
    'manager', 'sr. manager', 'senior manager', 'assistant manager',
    'general manager', 'gm', 'account manager', 'project manager',
    'product manager', 'program manager', 'operations manager',
    // sales / bd / marketing
    'sales', 'sales executive', 'sales manager', 'business development',
    'bd', 'bdm', 'marketing', 'brand', 'growth', 'partnerships',
    // procurement / sourcing (our ICP)
    'sourcing', 'procurement', 'purchase', 'buyer', 'supply chain',
    'category manager', 'vendor', 'materials',
    // engineering / product
    'engineer', 'developer', 'architect', 'designer', 'consultant',
    'analyst', 'specialist', 'strategist',
    // founder / owner
    'founder', 'co-founder', 'cofounder', 'owner', 'proprietor',
    'partner', 'principal',
    // HR / finance / legal / admin
    'hr', 'human resources', 'recruiter', 'talent', 'accountant',
    'finance', 'controller', 'auditor', 'lawyer', 'advocate',
    'administrator', 'coordinator', 'executive assistant',
    // operations
    'operations', 'logistics', 'production', 'quality',
    // relationship words
    'lead', 'senior', 'junior', 'associate', 'representative', 'rep',
    'officer', 'assistant', 'trainee', 'intern',
  };

  static const _companyMarkers = {
    'inc', 'inc.', 'llc', 'ltd', 'ltd.', 'limited', 'corp', 'corp.',
    'corporation', 'company', 'co.', 'gmbh', 'ag', 'sa', 's.a.',
    'sarl', 'srl', 'bv', 'nv', 'pvt', 'pvt.', 'private', 'plc',
    'group', 'holdings', 'industries', 'enterprises', 'ventures',
    'solutions', 'systems', 'technologies', 'services', 'consulting',
    'international', 'global', 'worldwide', 'associates', 'partners',
    'trading', 'exports', 'imports', 'traders', 'manufacturers',
    'foundation', 'trust', 'society', 'org', 'organization',
  };

  static const _streetMarkers = {
    'street', 'st', 'st.', 'road', 'rd', 'rd.', 'avenue', 'ave', 'ave.',
    'boulevard', 'blvd', 'lane', 'ln', 'drive', 'dr', 'dr.', 'plaza',
    'square', 'sq', 'sector', 'block', 'floor', 'flr', 'fl', 'suite',
    'ste', 'unit', 'apt', 'building', 'bldg', 'tower', 'complex',
    'park', 'phase', 'nagar', 'colony', 'marg', 'chowk', 'gali',
    'highway', 'hwy', 'circle', 'crescent', 'ct', 'court', 'path',
  };

  /// Compact country list — enough to identify the last address line.
  /// Users can edit on review if we're wrong.
  static const _countries = {
    'india', 'usa', 'u.s.a.', 'united states', 'united states of america',
    'uk', 'u.k.', 'united kingdom', 'england', 'scotland', 'wales',
    'canada', 'australia', 'new zealand', 'germany', 'france', 'italy',
    'spain', 'portugal', 'netherlands', 'belgium', 'switzerland', 'sweden',
    'norway', 'denmark', 'finland', 'poland', 'greece', 'ireland',
    'austria', 'czech republic', 'hungary', 'romania', 'turkey', 'russia',
    'ukraine', 'israel', 'uae', 'united arab emirates', 'saudi arabia',
    'qatar', 'kuwait', 'bahrain', 'oman', 'jordan', 'lebanon', 'egypt',
    'south africa', 'nigeria', 'kenya', 'ghana', 'morocco', 'tunisia',
    'china', 'japan', 'south korea', 'korea', 'taiwan', 'hong kong',
    'singapore', 'malaysia', 'indonesia', 'thailand', 'vietnam',
    'philippines', 'pakistan', 'bangladesh', 'sri lanka', 'nepal',
    'mexico', 'brazil', 'argentina', 'chile', 'colombia', 'peru',
  };

  // --- entry point --------------------------------------------------------

  static ExtractedCard parse(List<OcrLine> lines) {
    if (lines.isEmpty) return const ExtractedCard(confidence: 0);

    // Normalize each line: OCR frequently glues words on rotated / small
    // text (e.g. "ZonalHead" → "Zonal Head"). Split camelCase-style
    // concatenations back into separate tokens BEFORE any classification.
    final ordered = lines
        .map((l) => OcrLine(
              text: _splitGluedWords(l.text),
              x: l.x, y: l.y, w: l.w, h: l.h, confidence: l.confidence,
            ))
        .toList()
      ..sort((a, b) {
        if ((a.cy - b.cy).abs() < math.max(a.h, b.h) * 0.6) {
          return a.cx.compareTo(b.cx);
        }
        return a.cy.compareTo(b.cy);
      });

    final joined = ordered.map((l) => l.text).join(' ');
    // OCR often inserts spaces around the "@" (`pawan @ vinnichemicals.com`)
    // or breaks the email across word boundaries. Normalize before matching:
    // strip whitespace immediately around "@", and stray spaces around dots.
    final normalizedForEmail = _normalizeEmailText(joined);

    // Regex-driven fields (deterministic).
    final email = _emailRe.firstMatch(normalizedForEmail)?.group(0);

    final phones = _extractPhones(ordered);
    final phone = phones.isNotEmpty ? phones[0] : null;
    final altPhone = phones.length > 1 ? phones[1] : null;

    final website = _pickWebsite(joined, email);

    // Classify each line. A line is "claimed" for extraction ONLY when its
    // dominant content is a URL/email/phone (>60% of chars). This prevents
    // a line like "GALAXY SIVTEK www.galaxysivtek.com" from being lost to
    // the URL claim and forcing the address text into the Company slot.
    final claimed = <int>{}; // indexes in `ordered`
    for (var i = 0; i < ordered.length; i++) {
      final raw = ordered[i].text;
      final normalized = _normalizeEmailText(raw);
      if (_lineIsDominatedBy(normalized, _emailRe) ||
          _lineIsDominatedBy(raw, _phoneRe) ||
          (_containsAtSymbol(raw) && normalized.contains('@'))) {
        claimed.add(i);
        continue;
      }
      // URL-only line: whole line is just a website like "www.example.com".
      final urlMatch = _urlRe.firstMatch(raw);
      if (urlMatch != null &&
          urlMatch.group(0)!.length >= raw.trim().length * 0.75) {
        claimed.add(i);
      }
    }

    // Designation & company.
    int? designationIdx;
    int? companyIdx;
    for (var i = 0; i < ordered.length; i++) {
      if (claimed.contains(i)) continue;
      final t = ordered[i].text.trim();
      // Skip section-header lines like "MarketingOffice:" or "Contact:".
      if (t.endsWith(':') || t.endsWith('|')) continue;
      final low = _norm(t);
      if (designationIdx == null && _hasTitleKeyword(low)) {
        designationIdx = i;
        continue;
      }
      if (companyIdx == null && _hasCompanyMarker(low)) {
        companyIdx = i;
      }
    }
    if (designationIdx != null) claimed.add(designationIdx);
    if (companyIdx != null) claimed.add(companyIdx);

    // Name: the biggest un-claimed line in the top ~55% of the card that
    // looks like a person's name. Falls back to biggest un-claimed line.
    final imgHeight = _imageHeight(ordered);
    int? nameIdx;
    double bestScore = -1;
    for (var i = 0; i < ordered.length; i++) {
      if (claimed.contains(i)) continue;
      final line = ordered[i];
      if (!_looksLikePersonName(line.text)) continue;
      // Score = height (font-size proxy) - Y penalty for lines in bottom half.
      final yPenalty = (line.cy / (imgHeight == 0 ? 1 : imgHeight)) * line.h;
      final score = line.h - 0.6 * yPenalty;
      if (score > bestScore) {
        bestScore = score;
        nameIdx = i;
      }
    }
    if (nameIdx != null) claimed.add(nameIdx);

    // If we still don't have a company, take the biggest un-claimed
    // multi-word line (companies are usually prominent) — but exclude lines
    // that clearly look like part of the address block (street markers,
    // postal codes, digit-heavy lines with commas).
    if (companyIdx == null) {
      double best = -1;
      for (var i = 0; i < ordered.length; i++) {
        if (claimed.contains(i)) continue;
        final l = ordered[i];
        final t = l.text.trim();
        if (_containsAtSymbol(t)) continue;
        final low = _norm(t);
        if (_hasStreetMarker(low)) continue;
        if (_postalRe.hasMatch(t)) continue;
        if (_countries.contains(low)) continue;
        // Digit-heavy line with commas is almost always an address fragment.
        final digitCount = RegExp(r'\d').allMatches(t).length;
        if (digitCount >= 4 && t.contains(',')) continue;
        final words = t.split(RegExp(r'\s+')).length;
        if (words < 2) continue;
        if (l.h > best) {
          best = l.h;
          companyIdx = i;
        }
      }
      if (companyIdx != null) claimed.add(companyIdx);
    }

    // Address: collect leftover lines that look address-y and are
    // vertically clustered near the bottom. NEVER pick a line that contains
    // "@" — that's an email that slipped past claiming.
    final addressLines = <int>[];
    for (var i = 0; i < ordered.length; i++) {
      if (claimed.contains(i)) continue;
      final t = ordered[i].text;
      if (_containsAtSymbol(t)) continue;
      final low = _norm(t);
      final hasStreet = _hasStreetMarker(low);
      final hasPostal = _postalRe.hasMatch(t);
      final hasComma = t.contains(',');
      final hasCountry = _countries.contains(low);
      final hasDigits = RegExp(r'\d').hasMatch(t);
      if (hasStreet || hasPostal || hasCountry ||
          (hasComma && hasDigits) ||
          (hasComma && t.split(' ').length >= 3)) {
        addressLines.add(i);
      }
    }
    // Fallback only if we found nothing address-y. Still skip email lines.
    if (addressLines.isEmpty) {
      for (var i = 0; i < ordered.length; i++) {
        if (claimed.contains(i)) continue;
        final t = ordered[i].text.trim();
        if (t.length < 5) continue;
        if (RegExp(r'^\d+$').hasMatch(t)) continue;
        if (_containsAtSymbol(t)) continue;
        addressLines.add(i);
        if (addressLines.length >= 3) break;
      }
    }
    for (final i in addressLines) claimed.add(i);

    final address = addressLines.isEmpty
        ? null
        : addressLines.map((i) => ordered[i].text.trim()).join(', ');

    // City & country from address.
    String? city;
    String? country;
    if (address != null) {
      final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        final lastLow = _norm(parts.last);
        if (_countries.contains(lastLow)) {
          country = _titleCase(parts.last);
          if (parts.length >= 2) city = _cityFromAddressPart(parts[parts.length - 2]);
        } else {
          // No known country → guess city from last comma part.
          city = _cityFromAddressPart(parts.last);
        }
      }
    }

    // Assemble.
    final name = nameIdx == null ? null : _titleCase(ordered[nameIdx].text);
    final designation = designationIdx == null
        ? null
        : _titleCase(ordered[designationIdx].text);
    final company = companyIdx == null
        ? null
        : _cleanCompany(ordered[companyIdx].text);

    // Confidence: fraction of the 4 core fields filled.
    final core = [name, company, email, phone]
        .where((v) => v != null && v.trim().isNotEmpty)
        .length;

    return ExtractedCard(
      fullName: name,
      designation: designation,
      companyName: company,
      email: email,
      phone: phone,
      altPhone: altPhone,
      website: website,
      address: address,
      city: city,
      country: country,
      confidence: core / 4.0,
    );
  }

  // --- helpers ------------------------------------------------------------

  static List<String> _extractPhones(List<OcrLine> lines) {
    // Iterate lines top-to-bottom, so index 0 = topmost (usually primary).
    final phones = <String>[];
    final seenDigits = <String>{};
    for (final l in lines) {
      for (final m in _phoneRe.allMatches(l.text)) {
        final raw = m.group(0)!.trim();
        final digits = raw.replaceAll(RegExp(r'\D'), '');
        // 7 digits minimum (very short local codes), 15 max (E.164 upper bound).
        if (digits.length < 7 || digits.length > 15) continue;
        if (seenDigits.contains(digits)) continue;
        seenDigits.add(digits);
        phones.add(_cleanPhone(raw));
      }
    }
    return phones;
  }

  static String _cleanPhone(String raw) {
    // Collapse repeated whitespace, normalize dashes.
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _pickWebsite(String text, String? excludeEmail) {
    // Work on email-normalized text so a URL that's actually the tail of an
    // email like "pawan @ site.com" is correctly recognized as belonging to
    // the email, not as a standalone website.
    final normalized = _normalizeEmailText(text);
    final emailDomain = excludeEmail == null
        ? null
        : excludeEmail.contains('@')
            ? excludeEmail.split('@').last.toLowerCase()
            : null;

    for (final m in _urlRe.allMatches(normalized)) {
      final url = m.group(0)!.trim();
      // Skip anything that's part of an email address.
      if (url.contains('@')) continue;
      // Skip if this URL is preceded by an "@" — it's the domain of the email.
      final start = m.start;
      if (start > 0 && normalized[start - 1] == '@') continue;
      // Skip if it exactly matches the email's domain.
      final host = url
          .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
          .split('/')
          .first
          .toLowerCase();
      if (emailDomain != null && host == emailDomain) continue;
      // Reject "1.5" style false positives — need at least one letter in host.
      if (!RegExp(r'[A-Za-z]').hasMatch(host)) continue;
      return host;
    }
    return null;
  }

  /// Fraction of `s`'s trimmed length covered by the FIRST match of `re`.
  /// True when the match spans more than 60% of the visible line.
  static bool _lineIsDominatedBy(String s, RegExp re) {
    final t = s.trim();
    if (t.isEmpty) return false;
    final m = re.firstMatch(t);
    if (m == null) return false;
    return m.group(0)!.length >= t.length * 0.6;
  }

  /// Does the line contain an "@" — possibly with surrounding whitespace,
  /// meaning it's part of an email address the OCR broke apart.
  static bool _containsAtSymbol(String s) =>
      s.contains('@') || RegExp(r'\s@\s').hasMatch(s);

  /// Split OCR-glued compound words on camelCase or letter/digit boundaries:
  ///   "ZonalHead"          → "Zonal Head"
  ///   "SIEVING&FILTERING"  → "SIEVING & FILTERING"  (no-op — separator is
  ///                          already whitespace-adjacent in most cards)
  ///   "IEast"              → "I East"
  /// Purely local — doesn't touch URLs / emails (they have dots/@).
  static String _splitGluedWords(String s) {
    if (s.contains('@') || s.contains('://')) return s;
    var out = s;
    // Lower→Upper transitions inside a token: "ZonalHead" → "Zonal Head".
    out = out.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    // Uppercase followed by Upper+lower: "IEast" → "I East".
    out = out.replaceAllMapped(
      RegExp(r'([A-Z])([A-Z][a-z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return out;
  }

  /// Rejoin emails that OCR split across whitespace (e.g. `pawan @ site.com`).
  static String _normalizeEmailText(String s) {
    // Collapse spaces around "@" and around dots when they sit between
    // alphanumeric characters (defensive against OCR line-breaks inside URLs).
    var out = s.replaceAll(RegExp(r'\s*@\s*'), '@');
    out = out.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])\s+\.\s*([A-Za-z0-9])'),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    out = out.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])\.\s+([A-Za-z0-9])'),
      (m) => '${m.group(1)}.${m.group(2)}',
    );
    return out;
  }

  static String _domainOf(String url) {
    return url
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
        .split('/')
        .first
        .toLowerCase();
  }

  static bool _looksLikeUrl(String s) => _urlRe.hasMatch(s) && !s.contains('@');

  /// Word-boundary match after stripping trailing periods from the keyword,
  /// then allowing an optional period. "pvt." → matches "pvt" and "pvt.".
  static bool _matchesAny(String lowNorm, Set<String> keywords) {
    for (final k in keywords) {
      final stem = k.replaceAll(RegExp(r'\.+$'), '').trim();
      if (stem.isEmpty) continue;
      if (stem.contains(' ')) {
        // Multi-word markers ("head of", "vice president"): substring match.
        if (lowNorm.contains(stem)) return true;
      } else {
        if (RegExp('\\b${RegExp.escape(stem)}\\b\\.?').hasMatch(lowNorm)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _hasTitleKeyword(String lowNorm) =>
      _matchesAny(lowNorm, _titleKeywords);

  static bool _hasCompanyMarker(String lowNorm) =>
      _matchesAny(lowNorm, _companyMarkers);

  static bool _hasStreetMarker(String lowNorm) =>
      _matchesAny(lowNorm, _streetMarkers);

  static bool _looksLikePersonName(String s) {
    final t = s.trim();
    // Real names are short. This also rejects marketing taglines like
    // "Performance Enhancing Additive" that would otherwise pass the
    // "2-4 alphabetic tokens" heuristic.
    if (t.length < 3 || t.length > 28) return false;
    if (RegExp(r'\d').hasMatch(t)) return false;
    if (t.contains('@') || t.contains('/') || t.contains('|') ||
        t.contains(':') || t.endsWith('.')) return false;
    final tokens = t.split(RegExp(r'\s+'));
    if (tokens.length < 2 || tokens.length > 4) return false;
    for (final tok in tokens) {
      // allow initials like "J." or names with hyphens/apostrophes
      if (!RegExp(r"^[A-Za-z][A-Za-z'\-\.]{0,}$").hasMatch(tok)) return false;
      // No single name token should exceed 14 chars — marketing compound
      // words ("Enhancing", "Chemicals") slip in otherwise.
      if (tok.length > 14) return false;
    }
    // Reject if any token ends with common marketing/gerund suffixes.
    // These almost never appear in real names.
    const marketingSuffixes = ['ing', 'tion', 'ment', 'ness', 'ology'];
    final low = _norm(t);
    for (final tok in tokens) {
      final tl = tok.toLowerCase();
      for (final suf in marketingSuffixes) {
        if (tl.length > suf.length + 2 && tl.endsWith(suf)) return false;
      }
    }
    // reject if any token is a company marker or title keyword
    if (_hasCompanyMarker(low)) return false;
    if (_hasTitleKeyword(low)) return false;
    return true;
  }

  static String _cleanCompany(String s) {
    // Drop trailing "|" or "—" separators, keep case as-is (companies use
    // mixed case intentionally); only title-case if the line is ALL CAPS.
    final t = s.trim().replaceAll(RegExp(r'[\|—]+$'), '').trim();
    if (t == t.toUpperCase() && t.length > 4) return _titleCase(t);
    return t;
  }

  static String _cityFromAddressPart(String s) {
    // Strip trailing postal code, keep the leading word run.
    final withoutPostal = s.replaceAll(_postalRe, '').trim();
    // Take the first 1-3 words as the city guess.
    final words = withoutPostal
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return _titleCase(s);
    return _titleCase(words.take(3).join(' '));
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _titleCase(String s) {
    final parts = s.trim().split(RegExp(r'(\s+)'));
    final buf = StringBuffer();
    for (final p in parts) {
      if (p.isEmpty || RegExp(r'^\s+$').hasMatch(p)) {
        buf.write(p);
        continue;
      }
      // Keep known all-caps abbreviations (LLC, Inc., CEO) as-is when short.
      final upper = p.toUpperCase();
      if (p == upper && p.length <= 4) {
        buf.write(p);
        continue;
      }
      buf.write(p[0].toUpperCase());
      buf.write(p.substring(1).toLowerCase());
    }
    return buf.toString();
  }

  static double _imageHeight(List<OcrLine> lines) {
    double maxY = 0;
    for (final l in lines) {
      if (l.y + l.h > maxY) maxY = l.y + l.h;
    }
    return maxY;
  }
}
