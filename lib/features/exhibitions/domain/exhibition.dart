import 'package:flutter/foundation.dart';

/// A named event / trade show that groups the leads scanned during it.
///
/// Now backed by its own DB table (`public.exhibitions`) so it has an
/// identity, a creation date, and can be renamed/deleted. Leads still
/// reference it by name in `leads.event_name` for backward-compat and
/// so an unknown folder never orphans the scan.
@immutable
class Exhibition {
  const Exhibition({
    required this.id,
    required this.name,
    required this.createdAt,
    this.leadCount = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// How many leads currently belong to this folder. Derived on the
  /// client from the leads stream so we don't need a second query.
  final int leadCount;

  bool get isEmpty => name.trim().isEmpty;

  Exhibition copyWith({String? name, DateTime? createdAt, int? leadCount}) =>
      Exhibition(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        leadCount: leadCount ?? this.leadCount,
      );
}
