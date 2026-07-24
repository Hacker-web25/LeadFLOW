import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/app_providers.dart';
import '../domain/pending_action.dart';

/// Every pending / done action for one lead. Invalidate after a save
/// (voice note, manual add) or a mark-done tap.
final pendingActionsProvider =
    FutureProvider.family<List<PendingAction>, String>((ref, leadId) async {
  final r = await ref.watch(actionRepositoryProvider).actionsForLead(leadId);
  return r.when(ok: (a) => a, err: (f) => throw f);
});

/// Pending-action count keyed by lead id — feeds the badge on lead cards.
/// Refetched implicitly when the leads stream refreshes, so it stays
/// in sync without a manual invalidate on every mutation.
final pendingCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final r = await ref.watch(actionRepositoryProvider).pendingCounts();
  return r.valueOrNull ?? const <String, int>{};
});
