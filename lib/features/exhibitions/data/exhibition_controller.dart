import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../leads/domain/lead.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../domain/exhibition.dart';

/// Currently-active exhibition. Persists across app restarts via
/// [SharedPreferences]. When set, every new scan is tagged with this
/// event so the Folders view can group by it later.
class CurrentExhibitionController extends AsyncNotifier<Exhibition?> {
  static const _key = 'current_exhibition';

  @override
  Future<Exhibition?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null || v.trim().isEmpty) return null;
    return Exhibition(v);
  }

  Future<void> set(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_key);
      state = const AsyncData(null);
      return;
    }
    await prefs.setString(_key, trimmed);
    state = AsyncData(Exhibition(trimmed));
  }

  Future<void> clear() => set('');
}

final currentExhibitionProvider =
    AsyncNotifierProvider<CurrentExhibitionController, Exhibition?>(
        CurrentExhibitionController.new);

/// All distinct exhibition names the signed-in user has ever tagged.
/// Derived from the live leads stream — no separate DB table needed.
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
