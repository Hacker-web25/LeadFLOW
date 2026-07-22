import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/lf_search_field.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../leads/domain/lead_filters.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../../leads/presentation/widgets/lead_card.dart';

/// Global search across names, companies, designations and emails.
/// Kept independent of the Leads tab filters.
final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider = Provider((ref) {
  final query = ref.watch(_searchQueryProvider);
  final filters = LeadFilters(query: query);
  return ref.watch(leadsStreamProvider).whenData(filters.apply);
});

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider);
    final results = ref.watch(_searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x3),
            child: LfSearchField(
              autofocus: false,
              onChanged: (q) => ref.read(_searchQueryProvider.notifier).state = q,
            ),
          ),
          Expanded(
            child: query.trim().isEmpty
                ? const LfEmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search your pipeline',
                    message:
                        'Find any lead by name, company, designation or email.',
                  )
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => LfErrorState(
                      message: 'Search is unavailable right now.',
                      onRetry: () => ref.invalidate(leadsStreamProvider),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return LfEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message: 'Nothing in your pipeline matches "$query".',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                            0, AppSpacing.screenH, AppSpacing.x8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.x2),
                        itemBuilder: (_, i) => LeadCard(lead: items[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
