import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../exhibitions/domain/exhibition.dart';
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

/// Folders view: shows every folder (exhibitions row) plus the "Untagged"
/// bucket for leads with no folder. Tap opens the folder; overflow menu
/// renames or deletes. Untagged is always last.
class _FoldersView extends ConsumerStatefulWidget {
  const _FoldersView({required this.leads});
  final List<Lead> leads;

  @override
  ConsumerState<_FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends ConsumerState<_FoldersView> {
  // Which folder is currently opened, or null for the top-level list.
  // We identify open folders by name — that's what leads.event_name uses,
  // and it works uniformly for real folders (rows) and legacy names.
  String? _openFolder;
  bool _openUntagged = false;

  @override
  Widget build(BuildContext context) {
    // Bucket the currently-filtered leads by their event_name.
    final buckets = <String, List<Lead>>{};
    final untagged = <Lead>[];
    for (final l in widget.leads) {
      final name = l.eventName?.trim();
      if (name == null || name.isEmpty) {
        untagged.add(l);
      } else {
        (buckets[name] ??= []).add(l);
      }
    }
    final exhibitions =
        ref.watch(exhibitionsProvider).valueOrNull ?? const <Exhibition>[];
    final currentExh = ref.watch(currentExhibitionProvider).valueOrNull;

    // If a folder is currently open, render its leads.
    if (_openUntagged) {
      return _FolderOpen(
        title: 'Untagged',
        subtitle: null,
        leads: untagged,
        onBack: () => setState(() => _openUntagged = false),
      );
    }
    if (_openFolder != null) {
      final list = buckets[_openFolder] ?? const <Lead>[];
      final exh = exhibitions
          .where((e) => e.name.toLowerCase() == _openFolder!.toLowerCase())
          .firstOrNull;
      return _FolderOpen(
        title: _openFolder!,
        subtitle: exh == null
            ? null
            : 'Created ${DateFormat('d MMM yyyy').format(exh.createdAt)}',
        leads: list,
        onBack: () => setState(() => _openFolder = null),
      );
    }

    // Compose the folder list — one entry per exhibitions row + one for
    // every event_name found on a lead but missing from exhibitions (a
    // legacy name from before folders were a first-class table).
    final displayedNames = <String>{
      for (final e in exhibitions) e.name.toLowerCase(),
    };
    final adHoc = buckets.keys
        .where((n) => !displayedNames.contains(n.toLowerCase()))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
      children: [
        // Header: active folder + change / new buttons.
        LfCard(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(children: [
            const Icon(Icons.folder_special_outlined, color: AppColors.iris),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active folder',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: context.lf.inkTertiary)),
                    Text(currentExh?.name ?? 'None — new scans stay untagged',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
            ),
            TextButton(
              onPressed: () => ExhibitionPickerSheet.show(context),
              child: const Text('Manage'),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.x3),

        // Real folders — with created_at + rename/delete affordances.
        for (final e in exhibitions)
          _FolderTile(
            name: e.name,
            createdAt: e.createdAt,
            count: buckets[e.name]?.length ?? 0,
            highlighted: currentExh?.id == e.id ||
                currentExh?.name.toLowerCase() == e.name.toLowerCase(),
            onTap: () => setState(() => _openFolder = e.name),
            onRename: () => _promptRename(e),
            onDelete: () => _promptDelete(e),
          ),

        // Legacy names — no metadata; still openable + assignable.
        for (final name in adHoc)
          _FolderTile(
            name: name,
            createdAt: null,
            count: buckets[name]?.length ?? 0,
            highlighted: currentExh?.name.toLowerCase() == name.toLowerCase(),
            onTap: () => setState(() => _openFolder = name),
            onRename: null,
            onDelete: null,
          ),

        // Untagged always last.
        if (untagged.isNotEmpty)
          _FolderTile(
            name: 'Untagged',
            createdAt: null,
            count: untagged.length,
            highlighted: false,
            leadingIcon: Icons.inbox_outlined,
            onTap: () => setState(() => _openUntagged = true),
          ),
      ],
    );
  }

  Future<void> _promptRename(Exhibition e) async {
    final ctl = TextEditingController(text: e.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    final r = await ref
        .read(exhibitionRepositoryProvider)
        .rename(id: e.id, newName: newName);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);
    if (!mounted) return;
    r.when(
      ok: (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to $newName.'))),
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _promptDelete(Exhibition e) async {
    final count = widget.leads
        .where((l) => (l.eventName?.trim().toLowerCase() ?? '') ==
            e.name.toLowerCase())
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: Text(count == 0
            ? 'This folder is empty.'
            : '$count lead${count == 1 ? "" : "s"} will be untagged, '
                'not deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.hot))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(exhibitionRepositoryProvider).delete(e.id);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);
    final current = ref.read(currentExhibitionProvider).valueOrNull;
    if (current?.id == e.id) {
      await ref.read(currentExhibitionProvider.notifier).clear();
    }
    if (!mounted) return;
    r.when(
      ok: (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder deleted.'))),
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message))),
    );
  }
}

/// Renders one folder's leads with a back button.
class _FolderOpen extends StatelessWidget {
  const _FolderOpen({
    required this.title,
    required this.subtitle,
    required this.leads,
    required this.onBack,
  });
  final String title;
  final String? subtitle;
  final List<Lead> leads;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH, vertical: AppSpacing.x2),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: text.labelSmall
                          ?.copyWith(color: context.lf.inkTertiary)),
              ],
            ),
          ),
          Text('${leads.length}',
              style: text.labelLarge?.copyWith(color: context.lf.inkTertiary)),
        ]),
      ),
      Expanded(
        child: leads.isEmpty
            ? LfEmptyState(
                icon: Icons.badge_outlined,
                title: 'No leads in this folder yet',
                message: 'Scans made while this folder is active will land here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x8),
                itemCount: leads.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.x2),
                itemBuilder: (_, i) => LeadCard(lead: leads[i]),
              ),
      ),
    ]);
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.createdAt,
    required this.count,
    required this.highlighted,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.leadingIcon,
  });

  final String name;
  final DateTime? createdAt;
  final int count;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    final dateFmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
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
              Icon(leadingIcon ?? Icons.folder_rounded,
                  color: highlighted ? AppColors.iris : c.inkSecondary,
                  size: 26),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      if (createdAt != null)
                        Text(
                          'Created ${dateFmt.format(createdAt!)}',
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
                    style:
                        text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (onRename != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.inkTertiary),
                  onSelected: (v) {
                    if (v == 'rename' && onRename != null) onRename!();
                    if (v == 'delete' && onDelete != null) onDelete!();
                  },
                  itemBuilder: (_) => [
                    if (onRename != null)
                      const PopupMenuItem(
                          value: 'rename', child: Text('Rename')),
                    if (onDelete != null)
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: AppColors.hot))),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: c.inkTertiary),
                ),
            ]),
          ),
        ),
      ),
    );
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
