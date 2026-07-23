import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/app_providers.dart';
import '../../leads/domain/lead.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../domain/exhibition.dart';
import '../domain/exhibition_repository.dart';
import 'mock_exhibition_repository.dart';
import 'supabase_exhibition_repository.dart';

/// Exhibition repository — Supabase in real mode, in-memory in demo mode.
final exhibitionRepositoryProvider =
    Provider<ExhibitionRepository>((ref) {
  if (AppConfig.demoMode) return _mockRepo;
  return SupabaseExhibitionRepository(ref.watch(supabaseClientProvider));
});
final _mockRepo = MockExhibitionRepository();

/// All folders for the signed-in user, refreshed whenever the leads
/// stream changes (renames + new folders show up right away). The
/// [Exhibition.leadCount] on each entry is derived from the current
/// leads snapshot so we don't need a second query.
final exhibitionsProvider =
    FutureProvider<List<Exhibition>>((ref) async {
  // Kick a refresh whenever leads change so counts stay live.
  final leads = ref.watch(leadsStreamProvider).valueOrNull ?? const <Lead>[];
  final result = await ref.watch(exhibitionRepositoryProvider).listAll();
  final list = result.valueOrNull ?? const <Exhibition>[];

  // Bucket leads by their event_name for count-lookup.
  final counts = <String, int>{};
  for (final l in leads) {
    final name = l.eventName?.trim();
    if (name != null && name.isNotEmpty) {
      counts[name.toLowerCase()] = (counts[name.toLowerCase()] ?? 0) + 1;
    }
  }

  return list
      .map((e) => e.copyWith(leadCount: counts[e.name.toLowerCase()] ?? 0))
      .toList();
});

/// Currently-active folder. Persists across app restarts via
/// [SharedPreferences]. When set, every new scan is tagged with this
/// event so the Folders view can group by it later.
class CurrentExhibitionController extends AsyncNotifier<Exhibition?> {
  static const _key = 'current_exhibition_v2';
  static const _legacyKey = 'current_exhibition'; // v1 stored bare name

  @override
  Future<Exhibition?> build() async {
    // Whenever exhibitions change, we may need to refresh the identity
    // of the current one (e.g. after a rename).
    ref.watch(exhibitionsProvider);

    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString(_key);
    // Migrate legacy pref that only stored the name.
    if (name == null) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.trim().isNotEmpty) {
        name = legacy.trim();
        await prefs.setString(_key, name);
      }
    }
    if (name == null || name.trim().isEmpty) return null;

    // Look up the full Exhibition (with id + created_at) — creating it
    // on the server if the user picked a name from the legacy string
    // prefs but the row hasn't been backfilled yet.
    final result = await ref.read(exhibitionRepositoryProvider).create(name);
    return result.valueOrNull;
  }

  Future<void> setByName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_key);
      state = const AsyncData(null);
      return;
    }
    final result =
        await ref.read(exhibitionRepositoryProvider).create(trimmed);
    result.when(
      ok: (e) async {
        await prefs.setString(_key, e.name);
        state = AsyncData(e);
        ref.invalidate(exhibitionsProvider);
      },
      err: (_) async {
        // Fall back to just the name so scanning still works.
        await prefs.setString(_key, trimmed);
        state = AsyncData(Exhibition(
            id: '', name: trimmed, createdAt: DateTime.now()));
      },
    );
  }

  Future<void> setExhibition(Exhibition e) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, e.name);
    state = AsyncData(e);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(null);
  }
}

final currentExhibitionProvider =
    AsyncNotifierProvider<CurrentExhibitionController, Exhibition?>(
        CurrentExhibitionController.new);

/// Distinct exhibition names derived from the leads stream — used as a
/// fallback in the picker so folders the user typed before folders were
/// a first-class table still show up as "known" chips.
final knownExhibitionsProvider = Provider<List<String>>((ref) {
  final leads = ref.watch(leadsStreamProvider).valueOrNull ?? const <Lead>[];
  final set = <String>{};
  for (final l in leads) {
    final name = l.eventName?.trim();
    if (name != null && name.isNotEmpty) set.add(name);
  }
  final list = set.toList()..sort((a, b) => a.compareTo(b));
  return list;
});

/// Leads bucketed by exhibition. Untagged leads land in `null`.
final leadsByExhibitionProvider =
    Provider<Map<String?, List<Lead>>>((ref) {
  final leads = ref.watch(leadsStreamProvider).valueOrNull ?? const <Lead>[];
  final map = <String?, List<Lead>>{};
  for (final l in leads) {
    final key = (l.eventName?.trim().isEmpty ?? true) ? null : l.eventName!.trim();
    (map[key] ??= []).add(l);
  }
  return map;
});
