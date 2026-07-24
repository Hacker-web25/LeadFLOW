import 'package:flutter/foundation.dart';

/// The kind of follow-up action extracted from a voice note.
enum PendingActionKind {
  call('Call'),
  email('Send email'),
  whatsapp('WhatsApp'),
  sms('Send SMS'),
  meeting('Meeting'),
  other('Follow up');

  const PendingActionKind(this.label);
  final String label;
}

/// Where the action stands.
enum PendingActionStatus { pending, done, skipped }

/// Marks how the action will be executed. `manual` = the user does it;
/// the other values feed a future automation worker.
enum PendingActionAutomation { manual, queued, processing, automated }

/// A single "thing to do next" attached to a lead. Rendered as a checklist
/// row in Lead Detail and a badge on the lead card in the list.
@immutable
class PendingAction {
  const PendingAction({
    required this.id,
    required this.leadId,
    this.voiceNoteId,
    required this.kind,
    required this.description,
    this.dueAt,
    this.status = PendingActionStatus.pending,
    this.automation = PendingActionAutomation.manual,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String leadId;
  final String? voiceNoteId;
  final PendingActionKind kind;
  final String description;
  final DateTime? dueAt;
  final PendingActionStatus status;
  final PendingActionAutomation automation;
  final DateTime createdAt;
  final DateTime? completedAt;

  PendingAction copyWith({
    PendingActionStatus? status,
    DateTime? completedAt,
    PendingActionAutomation? automation,
  }) =>
      PendingAction(
        id: id,
        leadId: leadId,
        voiceNoteId: voiceNoteId,
        kind: kind,
        description: description,
        dueAt: dueAt,
        status: status ?? this.status,
        automation: automation ?? this.automation,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

/// The subset of a [PendingAction] that the AI can extract from a voice
/// note. `dueHint` is the raw phrase spoken (e.g. "next Tuesday"), which
/// we resolve to a concrete `dueAt` client-side.
@immutable
class PendingActionDraft {
  const PendingActionDraft({
    required this.kind,
    required this.description,
    this.dueHint,
  });

  final PendingActionKind kind;
  final String description;
  final String? dueHint;
}
