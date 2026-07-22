import 'package:intl/intl.dart';

extension DateX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// "2:40 PM" today, "Yesterday", else "12 Jul".
  String get relativeLabel {
    final now = DateTime.now();
    if (isToday) return DateFormat.jm().format(this);
    final yesterday = now.subtract(const Duration(days: 1));
    if (year == yesterday.year && month == yesterday.month && day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(this);
  }
}
