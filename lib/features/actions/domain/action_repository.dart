import '../../../core/utils/result.dart';
import 'pending_action.dart';

/// Contract for pending-action persistence.
abstract interface class ActionRepository {
  /// Every pending or done action for a lead, newest first.
  Future<Result<List<PendingAction>>> actionsForLead(String leadId);

  /// Pending count per lead — used to badge lead cards without pulling
  /// the whole action list into memory.
  Future<Result<Map<String, int>>> pendingCounts();

  /// Save a batch of drafts against a lead (e.g. straight from a voice
  /// note). Returns the persisted actions with ids + timestamps.
  Future<Result<List<PendingAction>>> createBatch({
    required String leadId,
    String? voiceNoteId,
    required List<PendingActionDraft> drafts,
  });

  /// Add a single manual action.
  Future<Result<PendingAction>> createOne({
    required String leadId,
    required PendingActionKind kind,
    required String description,
    DateTime? dueAt,
  });

  /// Mark done / undone. `done=false` moves it back to pending so users
  /// can undo a mistaken tap.
  Future<Result<void>> markDone(String id, {bool done = true});

  Future<Result<void>> delete(String id);
}
