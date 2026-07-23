import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/app_providers.dart';
import '../../../../core/utils/date_x.dart';
import '../../../follow_ups/domain/follow_up.dart';
import '../../domain/lead.dart';
import '../../domain/lead_filters.dart';

/// All leads, live from the repository.
final leadsStreamProvider = StreamProvider<List<Lead>>(
  (ref) => ref.watch(leadRepositoryProvider).watchLeads(),
);

/// Filter/sort/search criteria for the Leads tab.
final leadFiltersProvider =
    NotifierProvider<LeadFiltersNotifier, LeadFilters>(LeadFiltersNotifier.new);

class LeadFiltersNotifier extends Notifier<LeadFilters> {
  @override
  LeadFilters build() => LeadFilters.none;

  void setQuery(String q) => state = state.copyWith(query: q);
  void setSort(LeadSort s) => state = state.copyWith(sort: s);
  void replace(LeadFilters f) => state = f;
  void clear() => state = LeadFilters.none.copyWith(query: state.query);

  void toggleTemperature(LeadTemperature t) {
    final set = {...state.temperatures};
    set.contains(t) ? set.remove(t) : set.add(t);
    state = state.copyWith(temperatures: set);
  }
}

/// Leads after filters — what the list/grid renders.
final filteredLeadsProvider = Provider<AsyncValue<List<Lead>>>((ref) {
  final filters = ref.watch(leadFiltersProvider);
  return ref.watch(leadsStreamProvider).whenData(filters.apply);
});

/// Signed URL for a lead's card image (thumbnail-safe). Cached per lead —
/// Riverpod holds the result so the same URL is reused across the list
/// and detail screens.
final cardImageUrlProvider =
    FutureProvider.family<String?, String>((ref, leadId) async {
  final leads = ref.watch(leadsStreamProvider).valueOrNull;
  final lead = leads?.where((l) => l.id == leadId).firstOrNull;
  if (lead == null) return null;
  final r = await ref.watch(leadRepositoryProvider).cardImageUrl(lead);
  return r.valueOrNull;
});

/// List/grid toggle for the Leads tab.
final leadViewModeProvider = StateProvider<LeadViewMode>((ref) => LeadViewMode.list);

/// One lead by id (detail screen).
///
/// Deliberately uses `ref.read` (not `watch`) on the leads stream. If we
/// watched the stream, every poll tick would re-fire this provider even
/// when the data hadn't changed — the detail screen would rebuild every
/// 6–30 s, and the voice-note audio player would restart mid-playback.
/// Writers that mutate a lead already call `ref.invalidate(leadProvider(id))`
/// to force a refresh at the moment it matters.
final leadProvider = FutureProvider.family<Lead, String>((ref, id) async {
  final cached = ref
      .read(leadsStreamProvider)
      .valueOrNull
      ?.where((l) => l.id == id)
      .firstOrNull;
  if (cached != null) return cached;
  final result = await ref.read(leadRepositoryProvider).getLead(id);
  return result.when(ok: (l) => l, err: (f) => throw f);
});

final leadActivityProvider = FutureProvider.family<List<Activity>, String>((ref, leadId) async {
  final result = await ref.watch(leadRepositoryProvider).activityForLead(leadId);
  return result.when(ok: (a) => a, err: (f) => throw f);
});

/// Pending follow-ups, soonest first.
final followUpsStreamProvider = StreamProvider<List<FollowUp>>(
  (ref) => ref.watch(leadRepositoryProvider).watchFollowUps(),
);

final todaysFollowUpsProvider = Provider<AsyncValue<List<FollowUp>>>((ref) {
  return ref
      .watch(followUpsStreamProvider)
      .whenData((all) => all.where((f) => f.dueAt.isToday || f.dueAt.isBefore(DateTime.now())).toList());
});

/// Aggregate numbers for the dashboard stat row.
final leadStatsProvider = Provider<AsyncValue<LeadStats>>((ref) {
  final followUps = ref.watch(todaysFollowUpsProvider).valueOrNull?.length ?? 0;
  return ref.watch(leadsStreamProvider).whenData((leads) => LeadStats(
        total: leads.length,
        today: leads.where((l) => l.capturedAt.isToday).length,
        hot: leads.where((l) => l.temperature == LeadTemperature.hot).length,
        followUpsDueToday: followUps,
      ));
});

final recentActivityProvider = FutureProvider<List<Activity>>((ref) async {
  // Recompute when leads change so new scans appear immediately.
  ref.watch(leadsStreamProvider);
  final result = await ref.watch(leadRepositoryProvider).recentActivity(limit: 6);
  return result.when(ok: (a) => a, err: (f) => throw f);
});

