import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/lf_chip.dart';
import '../../../../core/widgets/lf_segmented.dart';
import '../../../../core/widgets/temperature_badge.dart';
import '../../domain/lead.dart';
import '../../domain/lead_filters.dart';
import '../providers/leads_providers.dart';

/// Distinct company names present in the pipeline, for the company filter.
final _companyOptionsProvider = Provider<List<String>>((ref) {
  final leads = ref.watch(leadsStreamProvider).valueOrNull ?? const [];
  final names = leads.map((l) => l.companyName).where((n) => n != '—').toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
});

/// Advanced filters bottom sheet. Edits a local copy; nothing applies
/// until "Show results" — cheap to explore, impossible to lose state.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const FilterSheet(),
      );

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late LeadFilters _draft = ref.read(leadFiltersProvider);

  void _update(LeadFilters next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x6),
              children: [
                Row(
                  children: [
                    Text('Filters', style: text.headlineSmall),
                    const Spacer(),
                    if (_draft.activeCount > 0)
                      TextButton(
                        onPressed: () => _update(LeadFilters.none.copyWith(query: _draft.query)),
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),

                _Group(
                  label: 'Lead temperature',
                  child: Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x2,
                    children: [
                      for (final t in LeadTemperature.values)
                        LfChoiceChip(
                          label: t.label,
                          selected: _draft.temperatures.contains(t),
                          leading: TemperatureBadge(t, dense: true),
                          onTap: () {
                            final set = {..._draft.temperatures};
                            set.contains(t) ? set.remove(t) : set.add(t);
                            _update(_draft.copyWith(temperatures: set));
                          },
                        ),
                    ],
                  ),
                ),

                _Group(
                  label: 'Requirement timeline',
                  child: Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x2,
                    children: [
                      for (final t in RequirementTimeline.values)
                        LfChoiceChip(
                          label: t.label,
                          selected: _draft.timelines.contains(t),
                          onTap: () {
                            final set = {..._draft.timelines};
                            set.contains(t) ? set.remove(t) : set.add(t);
                            _update(_draft.copyWith(timelines: set));
                          },
                        ),
                    ],
                  ),
                ),

                _Group(
                  label: 'Customer type',
                  child: Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x2,
                    children: [
                      for (final t in CustomerType.values)
                        LfChoiceChip(
                          label: t.label,
                          selected: _draft.customerTypes.contains(t),
                          onTap: () {
                            final set = {..._draft.customerTypes};
                            set.contains(t) ? set.remove(t) : set.add(t);
                            _update(_draft.copyWith(customerTypes: set));
                          },
                        ),
                    ],
                  ),
                ),

                if (ref.watch(_companyOptionsProvider).isNotEmpty)
                  _Group(
                    label: 'Company',
                    child: Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x2,
                      children: [
                        for (final name in ref.watch(_companyOptionsProvider))
                          LfChoiceChip(
                            label: name,
                            selected: _draft.companies.contains(name),
                            onTap: () {
                              final set = {..._draft.companies};
                              set.contains(name) ? set.remove(name) : set.add(name);
                              _update(_draft.copyWith(companies: set));
                            },
                          ),
                      ],
                    ),
                  ),

                _Group(
                  label: 'Decision maker',
                  child: _TriState(
                    value: _draft.decisionMaker,
                    onChanged: (v) => _update(_draft.copyWith(decisionMaker: v)),
                  ),
                ),
                _Group(
                  label: 'Export requirement',
                  child: _TriState(
                    value: _draft.exportRequirement,
                    onChanged: (v) => _update(_draft.copyWith(exportRequirement: v)),
                  ),
                ),
                _Group(
                  label: 'Sales team required',
                  child: _TriState(
                    value: _draft.salesTeamRequired,
                    onChanged: (v) => _update(_draft.copyWith(salesTeamRequired: v)),
                  ),
                ),

                _Group(
                  label: 'Sort by',
                  child: LfSegmented<LeadSort>(
                    options: LeadSort.values,
                    labelOf: (s) => s.label,
                    value: _draft.sort,
                    onChanged: (s) => _update(_draft.copyWith(sort: s)),
                  ),
                ),
              ],
            ),
          ),

          // Apply
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x4),
              child: FilledButton(
                onPressed: () {
                  ref.read(leadFiltersProvider.notifier).replace(_draft);
                  Navigator.of(context).pop();
                },
                child: const Text('Show results'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.eyebrow),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

/// Any / Yes / No selector for tri-state boolean filters.
class _TriState extends StatelessWidget {
  const _TriState({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LfSegmented<String>(
      options: const ['Any', 'Yes', 'No'],
      labelOf: (s) => s,
      value: switch (value) { null => 'Any', true => 'Yes', false => 'No' },
      onChanged: (s) =>
          onChanged(switch (s) { 'Yes' => true, 'No' => false, _ => null }),
    );
  }
}
