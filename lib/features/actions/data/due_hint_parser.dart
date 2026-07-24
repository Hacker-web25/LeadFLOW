/// Convert a spoken due-hint into a concrete DateTime.
///
/// The AI extracts phrases like "tomorrow", "next Tuesday 3pm", "in an
/// hour", "tonight" from voice-note transcripts. This is a small, boring
/// rule-based parser that resolves those to a Dart DateTime. If we can't
/// confidently resolve one, we return null and the action just shows up
/// without a due date — the user can still act on it.
abstract final class DueHintParser {
  static DateTime? parse(String? hint, {DateTime? from}) {
    if (hint == null) return null;
    final trimmed = hint.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final now = from ?? DateTime.now();

    // "in <n> <unit>"
    final rel =
        RegExp(r'^in\s+(\d+)\s+(minute|min|hour|hr|day|week|month)s?')
            .firstMatch(trimmed);
    if (rel != null) {
      final n = int.tryParse(rel.group(1)!) ?? 0;
      final unit = rel.group(2)!;
      if (unit.startsWith('min')) {
        return now.add(Duration(minutes: n));
      }
      if (unit.startsWith('hour') || unit.startsWith('hr')) {
        return now.add(Duration(hours: n));
      }
      if (unit == 'day') return now.add(Duration(days: n));
      if (unit == 'week') return now.add(Duration(days: n * 7));
      if (unit == 'month') return DateTime(now.year, now.month + n, now.day);
    }

    // Time-of-day extraction — reused by keyword branches below.
    final tod = _extractTime(trimmed);
    DateTime withTime(DateTime base) => tod == null
        ? DateTime(base.year, base.month, base.day, 9, 0)
        : DateTime(base.year, base.month, base.day, tod.$1, tod.$2);

    if (trimmed.contains('tonight')) {
      return DateTime(now.year, now.month, now.day, 20, 0);
    }
    if (trimmed.contains('this evening')) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    if (trimmed.contains('morning') && !trimmed.contains('tomorrow')) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (trimmed.contains('today')) {
      return withTime(now);
    }
    if (trimmed.contains('tomorrow')) {
      return withTime(now.add(const Duration(days: 1)));
    }

    // "next <weekday>" or bare "<weekday>"
    for (final entry in _weekdays.entries) {
      if (trimmed.contains(entry.key)) {
        final target = _nextWeekday(now, entry.value,
            forceNext: trimmed.contains('next'));
        return withTime(target);
      }
    }

    // "next week" without a specific day → Monday next week 9am
    if (trimmed.contains('next week')) {
      final daysToMon = (DateTime.monday - now.weekday + 7) % 7;
      final base = now
          .add(Duration(days: daysToMon == 0 ? 7 : daysToMon + 7));
      return withTime(base);
    }

    return null;
  }

  static const Map<String, int> _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static DateTime _nextWeekday(DateTime from, int weekday,
      {required bool forceNext}) {
    var diff = (weekday - from.weekday + 7) % 7;
    if (diff == 0 || forceNext) diff += 7;
    return from.add(Duration(days: diff));
  }

  /// Return (hour, minute) if a time expression like "3pm", "9:30 am",
  /// "at 4" appears in the hint.
  static (int, int)? _extractTime(String s) {
    final m = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(s);
    if (m == null) return null;
    var h = int.tryParse(m.group(1) ?? '') ?? -1;
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = m.group(3);
    if (h < 0 || h > 23) return null;
    if (ampm == 'pm' && h < 12) h += 12;
    if (ampm == 'am' && h == 12) h = 0;
    // Bare number without am/pm and no other date word — skip.
    if (ampm == null && !s.contains(':')) return null;
    return (h, min);
  }
}
