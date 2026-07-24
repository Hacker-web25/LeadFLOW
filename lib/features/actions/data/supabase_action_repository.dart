import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import '../domain/action_repository.dart';
import '../domain/pending_action.dart';
import 'due_hint_parser.dart';

class SupabaseActionRepository implements ActionRepository {
  SupabaseActionRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Result<List<PendingAction>>> actionsForLead(String leadId) async {
    try {
      final rows = await _client
          .from('pending_actions')
          .select()
          .eq('lead_id', leadId)
          .order('status')
          .order('due_at', ascending: true, nullsFirst: false)
          .order('created_at', ascending: false);
      return Ok(rows
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList());
    } catch (e) {
      return Err(AppFailure("Couldn't load pending actions.", cause: e));
    }
  }

  @override
  Future<Result<Map<String, int>>> pendingCounts() async {
    try {
      final rows = await _client
          .from('pending_actions')
          .select('lead_id')
          .eq('owner_id', _uid)
          .eq('status', 'pending');
      final counts = <String, int>{};
      for (final r in rows) {
        final id = (r as Map<String, dynamic>)['lead_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return Ok(counts);
    } catch (e) {
      return Err(AppFailure("Couldn't load action counts.", cause: e));
    }
  }

  @override
  Future<Result<List<PendingAction>>> createBatch({
    required String leadId,
    String? voiceNoteId,
    required List<PendingActionDraft> drafts,
  }) async {
    if (drafts.isEmpty) return const Ok([]);
    try {
      final now = DateTime.now();
      final payload = drafts.map((d) {
        final due = DueHintParser.parse(d.dueHint, from: now);
        return {
          'owner_id': _uid,
          'lead_id': leadId,
          if (voiceNoteId != null) 'voice_note_id': voiceNoteId,
          'kind': d.kind.name,
          'description': d.description,
          if (due != null) 'due_at': due.toUtc().toIso8601String(),
        };
      }).toList();
      final rows = await _client
          .from('pending_actions')
          .insert(payload)
          .select();
      return Ok(rows
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList());
    } catch (e) {
      return Err(AppFailure("Couldn't save pending actions.", cause: e));
    }
  }

  @override
  Future<Result<PendingAction>> createOne({
    required String leadId,
    required PendingActionKind kind,
    required String description,
    DateTime? dueAt,
  }) async {
    try {
      final row = await _client
          .from('pending_actions')
          .insert({
            'owner_id': _uid,
            'lead_id': leadId,
            'kind': kind.name,
            'description': description,
            if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
          })
          .select()
          .single();
      return Ok(_fromRow(row));
    } catch (e) {
      return Err(AppFailure("Couldn't save this action.", cause: e));
    }
  }

  @override
  Future<Result<void>> markDone(String id, {bool done = true}) async {
    try {
      await _client.from('pending_actions').update({
        'status': done ? 'done' : 'pending',
        'completed_at':
            done ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', id);
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure("Couldn't update this action.", cause: e));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _client.from('pending_actions').delete().eq('id', id);
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure("Couldn't delete this action.", cause: e));
    }
  }

  PendingAction _fromRow(Map<String, dynamic> r) => PendingAction(
        id: r['id'] as String,
        leadId: r['lead_id'] as String,
        voiceNoteId: r['voice_note_id'] as String?,
        kind: PendingActionKind.values.byName(r['kind'] as String),
        description: r['description'] as String,
        dueAt: r['due_at'] == null
            ? null
            : DateTime.parse(r['due_at'] as String).toLocal(),
        status: PendingActionStatus.values.byName(r['status'] as String),
        automation: PendingActionAutomation.values
            .byName(r['automation_status'] as String),
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        completedAt: r['completed_at'] == null
            ? null
            : DateTime.parse(r['completed_at'] as String).toLocal(),
      );
}
