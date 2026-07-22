import 'package:flutter/foundation.dart';

enum FollowUpStatus { pending, done, skipped }

@immutable
class FollowUp {
  const FollowUp({
    required this.id,
    required this.leadId,
    required this.leadName,
    required this.companyName,
    required this.dueAt,
    this.status = FollowUpStatus.pending,
    this.note,
  });

  final String id;
  final String leadId;
  final String leadName;
  final String companyName;
  final DateTime dueAt;
  final FollowUpStatus status;
  final String? note;

  FollowUp copyWith({FollowUpStatus? status}) => FollowUp(
        id: id,
        leadId: leadId,
        leadName: leadName,
        companyName: companyName,
        dueAt: dueAt,
        status: status ?? this.status,
        note: note,
      );
}
