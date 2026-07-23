import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_breakpoints.dart';
import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_pressable.dart';
import '../../../core/widgets/lf_search_field.dart';
import '../../../core/widgets/lf_skeleton.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../exhibitions/data/exhibition_controller.dart';
import '../../exhibitions/presentation/exhibition_picker_sheet.dart';
import '../domain/lead.dart';
import '../domain/lead_filters.dart';
import 'providers/leads_providers.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/lead_card.dart';
import '../../../core/theme/lf_colors.dart';

/// All leads: search, advanced filters, sort, list/grid.
class LeadListScreen extends ConsumerWidget {
  const LeadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(filteredLeadsProvider);
    final filters = ref.watch(leadFiltersProvider);
    final viewMode = ref.watch(leadViewModeProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads'),
        actions: [
          IconButton(
            tooltip: viewMode == LeadViewMode.folders
                ? 'Showing folders'
                : 'Sort by folder',
            icon: Icon(
              Icons.folder_rounded,
              color: viewMode == LeadViewMode.folders
                  ? AppColors.iris
                  : null,
            ),
            onPressed: () {
              ref.read(leadViewModeProvider.notifier).state =
                  viewMode == LeadViewMode.folders
                      ? LeadViewMode.list
                      : LeadViewMode.folders;
            },
          ),
          IconButton(
            tooltip: 'Bulk edit',
            icon: const Icon(Icons.table_rows_rounded),
            onPressed: () => context.push(Routes.leadsBulkEdit),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter + view toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x3),
            child: Row(
              children: [
                Expanded(
                  child: LfSearchField(
                    onChanged: (q) => ref.read(leadFiltersProvider.notifier).setQuery(q),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                _SquareAction(
                  icon: Icons.tune_rounded,
                  badgeCount: filters.activeCount,
                  onTap: () => FilterSheet.show(context),
                ),
                const SizedBox(width: AppSpacing.x2),
                _SquareAction(
                  icon: switch (viewMode) {
                    LeadViewMode.list => Icons.grid_view_rounded,
                    LeadViewMode.grid => Icons.folder_outlined,
                    LeadViewMode.folders => Icons.view_agenda_outlined,
                  },
                  onTap: () {
                    final next = switch (viewMode) {
                      LeadViewMode.list => LeadViewMode.grid,
                      LeadViewMode.grid => LeadViewMode.folders,
                      LeadViewMode.folders => LeadViewMode.list,
                    };
                    ref.read(leadViewModeProvider.notifier).state = next;
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: leads.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
                itemBuilder: (_, __) => const LfSkeleton(height: 80, radius: 16),
              ),
              // Errors here are almost always a transient blip on the
              // polling stream; surface the empty state instead of a
              // dead-end "try again" card. Real network problems retry
              // themselves silently on the next poll tick.
              error: (_, __) => LfEmptyState(
                icon: Icons.badge_outlined,
                title: 'No leads yet',
                message: 'Scan a business card to capture your first lead.',
                actionLabel: 'Scan a card',
                onAction: () => context.push(Routes.scan),
              ),
              data: (items) {
                if (items.isEmpty) {
                  final filtering = filters.activeCount > 0 || filters.query.isNotEmpty;
                  return LfEmptyState(
                    icon: filtering ? Icons.filter_alt_off_outlined : Icons.badge_outlined,
                    title: filtering ? 'No matches' : 'No leads yet',
                    message: filtering
                        ? 'No leads match the current filters.'
                        : 'Scan a business card to capture your first lead.',
                    actionLabel: filtering ? 'Clear filters' : 'Scan a card',
                    onAction: filtering
                        ? () => ref.read(leadFiltersProvider.notifier).clear()
                        : () => context.push(Routes.scan),
                  );
                }
                if (viewMode == LeadViewMode.folders) {
                  return _FoldersView(leads: items);
                }
                final grid = viewMode == LeadViewMode.grid || isTablet;
                if (!grid) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
                    itemBuilder: (_, i) => LeadCard(lead: items[i]),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isTablet ? 280 : 220,
                    mainAxisSpacing: AppSpacing.x2,
                    crossAxisSpacing: AppSpacing.x2,
                    childAspectRatio: 1.35,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => LeadGridTile(lead: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Folders view: groups leads by exhibition (event_name). Tapping a folder
/// filters the list to just that exhibition. "Untagged" is shown last.
class _FoldersView extends ConsumerStatefulWidget {
  const _FoldersView({required this.leads});
  final List<Lead> leads;

  @override
  ConsumerState<_FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends ConsumerState<_FoldersView> {
  String? _openFolder; // event_name; null before selection

  @override
  Widget build(BuildContext context) {
    // Bucket the currently-filtered leads by their event_name.
    final buckets = <String?, List<Lead>>{};
    for (final l in widget.leads) {
      final key = (l.eventName?.trim().isEmpty ?? true)
          ? null
          : l.eventName!.trim();
      (buckets[key] ??= []).add(l);
    }
    final currentExh = ref.watch(currentExhibitionProvider).valueOrNull;

    if (_openFolder != null) {
      final list = buckets[_openFolder] ?? const <Lead>[];
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH, vertical: AppSpacing.x2),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _openFolder = null),
            ),
            Expanded(
              child: Text(_openFolder!,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${list.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.lf.inkTertiary)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
            itemBuilder: (_, i) => LeadCard(lead: list[i]),
          ),
        ),
      ]);
    }

    // Order: current exhibition first, then others by name, untagged last.
    final entries = buckets.entries.toList()
      ..sort((a, b) {
        if (a.key == null) return 1;
        if (b.key == null) return -1;
        if (a.key == currentExh?.name) return -1;
        if (b.key == currentExh?.name) return 1;
        return a.key!.compareTo(b.key!);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
      children: [
        LfCard(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(children: [
            const Icon(Icons.folder_special_outlined, color: AppColors.iris),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current folder',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: context.lf.inkTertiary)),
                    Text(currentExh?.name ?? 'No exhibition',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
            ),
            TextButton(
              onPressed: () => ExhibitionPickerSheet.show(context),
              child: const Text('Change'),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.x3),
        for (final entry in entries) ...[
          _FolderTile(
            name: entry.key ?? 'Untagged',
            count: entry.value.length,
            hint: entry.value.isNotEmpty
                ? entry.value.first.capturedAt
                : null,
            highlighted: entry.key != null && entry.key == currentExh?.name,
            onTap: () => setState(() => _openFolder = entry.key),
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.count,
    required this.hint,
    required this.highlighted,
    required this.onTap,
  });

  final String name;
  final int count;
  final DateTime? hint;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    return Material(
      color: highlighted
          ? AppColors.iris.withValues(alpha: 0.10)
          : c.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
                color: highlighted ? AppColors.iris : c.hairline),
          ),
          child: Row(children: [
            Icon(Icons.folder_rounded,
                color: highlighted ? AppColors.iris : c.inkSecondary, size: 26),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600)),
                    if (hint != null)
                      Text(
                        'Latest: ${_relative(hint!)}',
                        style: text.labelSmall
                            ?.copyWith(color: c.inkTertiary),
                      ),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: c.inkTertiary),
          ]),
        ),
      ),
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'moments ago';
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({required this.icon, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return LfPressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: context.lf.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.lf.hairline),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 21, color: context.lf.ink),
            if (badgeCount > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(color: AppColors.iris, shape: BoxShape.circle),
                  child: Text('$badgeCount',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
