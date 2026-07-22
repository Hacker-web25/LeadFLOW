import 'package:flutter/foundation.dart';

/// A named event / trade show that groups the leads scanned during it.
/// Not backed by its own DB table — just a text label copied into
/// `leads.event_name` on save, so any string the user types is legal.
@immutable
class Exhibition {
  const Exhibition(this.name);
  final String name;

  bool get isEmpty => name.trim().isEmpty;
}
