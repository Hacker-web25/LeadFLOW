import 'package:uuid/uuid.dart';

import '../../../core/utils/result.dart';
import '../domain/action_repository.dart';
import '../domain/pending_action.dart';
import 'due_hint_parser.dart';

/// In-memory implementation used in demo mode.
class MockActionRepository implements ActionRepository {
  static const _uuid = Uuid();
  final List<PendingAction> _actions = [];

  @override
  Future<Result<List<PendingAction>>> actionsForLead(String leadId) async {
    final list = _actions.where((a) => a.leadId == leadId).toList()
      ..sort((a, b) {
        if (a.status != b.status) {
          return a.status.index.compareTo(b.status.index);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return Ok(list);
  }

  @override
  Future<Result<Map<String, int>>> pendingCounts() async {
    final map = <String, int>{};
    for (final a in _actions) {
      if (a.status == PendingActionStatus.pending) {
        map[a.leadId] = (map[a.leadId] ?? 0) + 1;
      }
    }
    return Ok(map);
  }

  @override
  Future<Result<List<PendingAction>>> createBatch({
    required String leadId,
    String? voiceNoteId,
    required List<PendingActionDraft> drafts,
  }) async {
    if (drafts.isEmpty) return const Ok([]);
    final now = DateTime.now();
    final out = <PendingAction>[];
    for (final d in drafts) {
      final a = PendingAction(
        id: _uuid.v4(),
        leadId: leadId,
        voiceNoteId: voiceNoteId,
        kind: d.kind,
        description: d.description,
        dueAt: DueHintParser.parse(d.dueHint, from: now),
        createdAt: now,
      );
      _actions.insert(0, a);
      out.add(a);
    }
    return Ok(out);
  }

  @override
  Future<Result<PendingAction>> createOne({
    required String leadId,
    required PendingActionKind kind,
    required String description,
    DateTime? dueAt,
  }) async {
    final a = PendingAction(
      id: _uuid.v4(),
      leadId: leadId,
      kind: kind,
      description: description,
      dueAt: dueAt,
      createdAt: DateTime.now(),
    );
    _actions.insert(0, a);
    return Ok(a);
  }

  @override
  Future<Result<void>> markDone(String id, {bool done = true}) async {
    final i = _actions.indexWhere((a) => a.id == id);
    if (i == -1) return const Err(AppFailure('Action not found.'));
    _actions[i] = _actions[i].copyWith(
      status: done ? PendingActionStatus.done : PendingActionStatus.pending,
      completedAt: done ? DateTime.now() : null,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _actions.removeWhere((a) => a.id == id);
    return const Ok(null);
  }
}
