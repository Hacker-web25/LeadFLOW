import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../data/exhibition_controller.dart';
import '../domain/exhibition.dart';

/// Bottom sheet for picking / creating / renaming / deleting the folder
/// (exhibition) that groups the current scans. Reachable from the scan
/// screen chip and the Leads AppBar.
class ExhibitionPickerSheet extends ConsumerStatefulWidget {
  const ExhibitionPickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const ExhibitionPickerSheet(),
      );

  @override
  ConsumerState<ExhibitionPickerSheet> createState() =>
      _ExhibitionPickerSheetState();
}

class _ExhibitionPickerSheetState
    extends ConsumerState<ExhibitionPickerSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    await ref.read(currentExhibitionProvider.notifier).setByName(name);
    ref.invalidate(exhibitionsProvider);
    if (!mounted) return;
    _controller.clear();
    Navigator.of(context).pop();
    _snack('Folder set: $name. New scans will land here.');
  }

  Future<void> _pick(Exhibition e) async {
    await ref.read(currentExhibitionProvider.notifier).setExhibition(e);
    if (!mounted) return;
    Navigator.of(context).pop();
    _snack('Folder set: ${e.name}. New scans will land here.');
  }

  Future<void> _clearActive() async {
    await ref.read(currentExhibitionProvider.notifier).clear();
    if (!mounted) return;
    Navigator.of(context).pop();
    _snack('Folder cleared. New scans stay untagged.');
  }

  Future<void> _rename(Exhibition e) async {
    final newName = await _promptName(context,
        title: 'Rename folder', initial: e.name);
    if (newName == null || newName.trim().isEmpty) return;
    final r = await ref
        .read(exhibitionRepositoryProvider)
        .rename(id: e.id, newName: newName);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);
    if (!mounted) return;
    r.when(
      ok: (_) => _snack('Renamed to $newName.'),
      err: (f) => _snack(f.message),
    );
  }

  Future<void> _delete(Exhibition e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${e.name}"?'),
        content: Text(e.leadCount == 0
            ? 'This folder is empty.'
            : '${e.leadCount} lead${e.leadCount == 1 ? "" : "s"} in this '
                'folder will be untagged, not deleted.'),
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
    if (ok != true) return;
    final r = await ref.read(exhibitionRepositoryProvider).delete(e.id);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);
    // If the deleted folder was the current one, clear it.
    final current = ref.read(currentExhibitionProvider).valueOrNull;
    if (current?.id == e.id) {
      await ref.read(currentExhibitionProvider.notifier).clear();
    }
    if (!mounted) return;
    r.when(
      ok: (_) => _snack('Folder deleted.'),
      err: (f) => _snack(f.message),
    );
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(exhibitionsProvider);
    final current = ref.watch(currentExhibitionProvider).valueOrNull;
    final knownNames = ref.watch(knownExhibitionsProvider);

    final exhibitions = async.valueOrNull ?? const <Exhibition>[];
    // Anything that shows up as a name on leads but isn't in the
    // exhibitions table yet — display it as an ad-hoc folder so the
    // user can still pick / rename / delete it.
    final adHocNames = knownNames
        .where((n) => !exhibitions.any(
            (e) => e.name.toLowerCase() == n.toLowerCase()))
        .toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenH,
          right: AppSpacing.screenH,
          top: AppSpacing.x2,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Exhibition folder', style: text.titleLarge),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'New scans will land in the selected folder until you switch.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x5),

              // ── Create new ─────────────────────────────────────────
              const LfSectionHeader('New folder'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    autofocus: false,
                    decoration: const InputDecoration(
                      hintText: 'e.g. IPPE Atlanta 2026',
                      prefixIcon: Icon(Icons.create_new_folder_outlined),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('Create'),
                ),
              ]),
              const SizedBox(height: AppSpacing.x5),

              // ── Existing folders ────────────────────────────────────
              const LfSectionHeader('Your folders'),
              if (exhibitions.isEmpty && adHocNames.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
                  child: Text('No folders yet — create one above.',
                      style: text.bodyMedium
                          ?.copyWith(color: context.lf.inkTertiary)),
                )
              else ...[
                for (final e in exhibitions)
                  _FolderRow(
                    exhibition: e,
                    isCurrent: current?.id == e.id ||
                        current?.name.toLowerCase() == e.name.toLowerCase(),
                    onTap: () => _pick(e),
                    onRename: () => _rename(e),
                    onDelete: () => _delete(e),
                  ),
                for (final name in adHocNames)
                  _AdHocFolderRow(
                    name: name,
                    isCurrent: current?.name.toLowerCase() == name.toLowerCase(),
                    onTap: () => ref
                        .read(currentExhibitionProvider.notifier)
                        .setByName(name)
                        .then((_) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      _snack('Folder set: $name.');
                    }),
                  ),
              ],
              const SizedBox(height: AppSpacing.x3),

              if (current != null)
                TextButton.icon(
                  onPressed: _clearActive,
                  icon: const Icon(Icons.folder_off_outlined),
                  label: const Text('Untag — no active folder'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.exhibition,
    required this.isCurrent,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Exhibition exhibition;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    final dateFmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: isCurrent ? AppColors.iris.withValues(alpha: 0.10) : c.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3, vertical: AppSpacing.x3),
            child: Row(children: [
              Icon(Icons.folder_rounded,
                  color: isCurrent ? AppColors.iris : c.inkSecondary),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exhibition.name,
                          style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        'Created ${dateFmt.format(exhibition.createdAt)}'
                        ' · ${exhibition.leadCount} lead'
                        '${exhibition.leadCount == 1 ? "" : "s"}',
                        style: text.labelSmall?.copyWith(color: c.inkTertiary),
                      ),
                    ]),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: c.inkTertiary),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: AppColors.hot))),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A folder-name that appears on leads but has no exhibitions row yet
/// (typed before folders became first-class). Tap to make it current;
/// promoting it to a full folder is done implicitly by `setByName`.
class _AdHocFolderRow extends StatelessWidget {
  const _AdHocFolderRow({
    required this.name,
    required this.isCurrent,
    required this.onTap,
  });
  final String name;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Material(
        color: isCurrent ? AppColors.iris.withValues(alpha: 0.10) : c.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3, vertical: AppSpacing.x3),
            child: Row(children: [
              Icon(Icons.folder_outlined, color: c.inkSecondary),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(name,
                    style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Reusable prompt for a folder name.
Future<String?> _promptName(BuildContext context,
    {required String title, String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Folder name'),
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
}
