/// Shared post-processing for AI-extracted card fields.
///
/// Every OCR/AI extractor eventually funnels its output through here so
/// the same fields land in the DB in the same shape regardless of source.
/// Fixes the "address shows up as ',,India' or 'Noida, ,'" family of bugs.
abstract final class FieldCleaners {
  /// Trim, collapse repeated whitespace, and drop the result if it's empty.
  static String? text(String? v) {
    if (v == null) return null;
    var s = v.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.isEmpty ? null : s;
  }

  /// Clean a comma-separated address so empty parts don't leave dangling
  /// commas ("Sector 80, , Noida, , India" → "Sector 80, Noida, India").
  /// Also strips leading/trailing separators and collapses whitespace.
  static String? address(String? v) {
    final base = text(v);
    if (base == null) return null;
    final parts = base
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// Same idea as [address] but capitalises the first letter of every word
  /// (useful for city, country, designation).
  static String? titleCase(String? v) {
    final base = text(v);
    if (base == null) return null;
    return base
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : w.length == 1
                ? w.toUpperCase()
                : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Compose a "city, country" style label from any number of parts,
  /// dropping empty/null ones so we never emit ", India" or "Delhi,".
  static String composeParts(Iterable<String?> parts, {String sep = ', '}) {
    return parts
        .map((p) => (p ?? '').trim())
        .where((p) => p.isNotEmpty)
        .join(sep);
  }
}
