import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../leads/domain/lead.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../data/exhibition_controller.dart';
import '../domain/exhibition.dart';

/// Central place for every "folder" user interaction — deliberately built
/// on plain [AlertDialog]s (not modal bottom sheets). We had a repeatable
/// bug where a modal sheet would render its scrim but never paint its
/// content on some Android devices; dialogs are boring and reliable.
class FolderDialogs {
  FolderDialogs._();

  // ─── Create a brand-new folder ────────────────────────────────────────
  //
  // Also sets it as the current folder and sweeps every UNTAGGED lead
  // captured today (local time) into it — so any scans taken before the
  // folder existed get filed automatically.
  static Future<Exhibition?> showCreate(
    BuildContext context,
    WidgetRef ref, {
    String? initial,
  }) async {
    final name = await _promptName(
      context,
      title: 'New folder',
      initial: initial ?? '',
      hint: 'e.g. IPPE Atlanta 2026',
      submitLabel: 'Create',
    );
    if (name == null || name.isEmpty) return null;

    final created =
        await ref.read(exhibitionRepositoryProvider).create(name);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);

    final folder = created.valueOrNull;
    if (folder == null) {
      created.when(
        ok: (_) {},
        err: (f) {
          if (context.mounted) _snack(context, f.message);
        },
      );
      return null;
    }

    // Make it the active folder so subsequent scans land here.
    await ref
        .read(currentExhibitionProvider.notifier)
        .setExhibition(folder);

    // Auto-file today's untagged scans into it.
    final moved = await ref
        .read(leadRepositoryProvider)
        .assignUntaggedFromDayToFolder(
            day: DateTime.now(), folderName: folder.name);
    ref.invalidate(leadsStreamProvider);
    ref.invalidate(exhibitionsProvider);

    if (context.mounted) {
      final movedCount = moved.valueOrNull ?? 0;
      _snack(
          context,
          movedCount == 0
              ? 'Folder "${folder.name}" created.'
              : 'Folder "${folder.name}" created. '
                  '$movedCount today\'s lead'
                  '${movedCount == 1 ? "" : "s"} auto-filed.');
    }
    return folder;
  }

  // ─── Rename an existing folder ────────────────────────────────────────
  static Future<void> showRename(
    BuildContext context,
    WidgetRef ref,
    Exhibition folder,
  ) async {
    final name = await _promptName(
      context,
      title: 'Rename folder',
      initial: folder.name,
      hint: 'Folder name',
      submitLabel: 'Save',
    );
    if (name == null || name.isEmpty || name == folder.name) return;

    final r = await ref
        .read(exhibitionRepositoryProvider)
        .rename(id: folder.id, newName: name);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);

    // If the renamed folder was the current one, refresh so its label
    // updates too.
    final current = ref.read(currentExhibitionProvider).valueOrNull;
    if (current?.id == folder.id) {
      r.when(
        ok: (updated) => ref
            .read(currentExhibitionProvider.notifier)
            .setExhibition(updated),
        err: (_) {},
      );
    }

    if (!context.mounted) return;
    r.when(
      ok: (_) => _snack(context, 'Renamed to $name.'),
      err: (f) => _snack(context, f.message),
    );
  }

  // ─── Delete a folder ──────────────────────────────────────────────────
  static Future<void> showDelete(
    BuildContext context,
    WidgetRef ref,
    Exhibition folder,
    int leadCount,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: Text(leadCount == 0
            ? 'This folder is empty.'
            : '$leadCount lead${leadCount == 1 ? "" : "s"} will be untagged, '
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
    if (ok != true || !context.mounted) return;

    final r =
        await ref.read(exhibitionRepositoryProvider).delete(folder.id);
    ref.invalidate(exhibitionsProvider);
    ref.invalidate(leadsStreamProvider);
    final current = ref.read(currentExhibitionProvider).valueOrNull;
    if (current?.id == folder.id) {
      await ref.read(currentExhibitionProvider.notifier).clear();
    }

    if (!context.mounted) return;
    r.when(
      ok: (_) => _snack(context, 'Folder deleted.'),
      err: (f) => _snack(context, f.message),
    );
  }

  // ─── Pick the active folder (scan screen) ─────────────────────────────
  //
  // A dialog with the existing folders + "None" + "New folder" option.
  static Future<void> showPickForScan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<_PickResult>(
      context: context,
      builder: (c) => _FolderPickerDialog(
        title: 'Exhibition folder',
        subtitle:
            'New scans will land in the selected folder until you switch.',
        allowNone: true,
        currentFolderName:
            ref.read(currentExhibitionProvider).valueOrNull?.name,
      ),
    );
    if (result == null || !context.mounted) return;

    switch (result.kind) {
      case _PickKind.none:
        await ref.read(currentExhibitionProvider.notifier).clear();
        if (context.mounted) {
          _snack(context, 'Folder cleared. New scans stay untagged.');
        }
        break;
      case _PickKind.pickExisting:
        final folder = result.folder!;
        await ref
            .read(currentExhibitionProvider.notifier)
            .setExhibition(folder);
        if (context.mounted) {
          _snack(context, 'Folder set: ${folder.name}. Scans will land here.');
        }
        break;
      case _PickKind.pickAdHoc:
        await ref
            .read(currentExhibitionProvider.notifier)
            .setByName(result.adHocName!);
        if (context.mounted) {
          _snack(context,
              'Folder set: ${result.adHocName}. Scans will land here.');
        }
        break;
      case _PickKind.createNew:
        await showCreate(context, ref);
        break;
    }
  }

  // ─── Move an existing lead into a folder ──────────────────────────────
  static Future<void> showMoveLead(
    BuildContext context,
    WidgetRef ref,
    Lead lead,
  ) async {
    final result = await showDialog<_PickResult>(
      context: context,
      builder: (c) => _FolderPickerDialog(
        title: 'Move to folder',
        subtitle: 'Currently in: ${lead.eventName ?? "no folder"}',
        allowNone: lead.eventName != null,
        currentFolderName: lead.eventName,
      ),
    );
    if (result == null || !context.mounted) return;

    String? newName;
    switch (result.kind) {
      case _PickKind.none:
        newName = null;
        break;
      case _PickKind.pickExisting:
        newName = result.folder!.name;
        break;
      case _PickKind.pickAdHoc:
        newName = result.adHocName;
        break;
      case _PickKind.createNew:
        final created = await showCreate(context, ref);
        if (created == null) return;
        newName = created.name;
        break;
    }

    final r = await ref.read(leadRepositoryProvider).setLeadFolder(
        leadId: lead.id, folderName: newName);
    ref.invalidate(leadProvider(lead.id));
    ref.invalidate(leadsStreamProvider);
    ref.invalidate(exhibitionsProvider);

    if (!context.mounted) return;
    r.when(
      ok: (_) => _snack(
          context,
          newName == null
              ? 'Lead removed from folder.'
              : 'Lead moved to $newName.'),
      err: (f) => _snack(context, f.message),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────
  static Future<String?> _promptName(
    BuildContext context, {
    required String title,
    required String initial,
    required String hint,
    required String submitLabel,
  }) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: Text(submitLabel)),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }
}

// ─── Picker dialog internals ────────────────────────────────────────────

enum _PickKind { none, pickExisting, pickAdHoc, createNew }

class _PickResult {
  const _PickResult.none()
      : kind = _PickKind.none,
        folder = null,
        adHocName = null;
  const _PickResult.existing(this.folder)
      : kind = _PickKind.pickExisting,
        adHocName = null;
  const _PickResult.adHoc(this.adHocName)
      : kind = _PickKind.pickAdHoc,
        folder = null;
  const _PickResult.createNew()
      : kind = _PickKind.createNew,
        folder = null,
        adHocName = null;

  final _PickKind kind;
  final Exhibition? folder;
  final String? adHocName;
}

class _FolderPickerDialog extends ConsumerWidget {
  const _FolderPickerDialog({
    required this.title,
    required this.subtitle,
    required this.allowNone,
    required this.currentFolderName,
  });

  final String title;
  final String subtitle;
  final bool allowNone;
  final String? currentFolderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exhibitionsAsync = ref.watch(exhibitionsProvider);
    final knownNames = ref.watch(knownExhibitionsProvider);
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    final dateFmt = DateFormat('d MMM yyyy');

    final exhibitions = exhibitionsAsync.valueOrNull ?? const <Exhibition>[];
    final known = <String>{
      for (final e in exhibitions) e.name.toLowerCase(),
    };
    final adHoc =
        knownNames.where((n) => !known.contains(n.toLowerCase())).toList();

    final hasAny = exhibitions.isNotEmpty || adHoc.isNotEmpty;
    // Cap dialog height so long folder lists stay scrollable inside the
    // dialog rather than blowing past the screen.
    final maxH = MediaQuery.sizeOf(context).height * 0.5;

    return AlertDialog(
      title: Text(title),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(subtitle,
                  style: text.bodyMedium?.copyWith(color: c.inkTertiary)),
              const SizedBox(height: 12),
              Flexible(
                child: !hasAny
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No folders yet.',
                            style: text.bodyMedium
                                ?.copyWith(color: c.inkTertiary)),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final e in exhibitions)
                            _tile(
                              context: context,
                              icon: Icons.folder_rounded,
                              title: e.name,
                              subtitle:
                                  'Created ${dateFmt.format(e.createdAt)}'
                                  ' · ${e.leadCount} lead'
                                  '${e.leadCount == 1 ? "" : "s"}',
                              isCurrent: currentFolderName?.toLowerCase() ==
                                  e.name.toLowerCase(),
                              onTap: () => Navigator.pop(
                                  context, _PickResult.existing(e)),
                            ),
                          for (final n in adHoc)
                            _tile(
                              context: context,
                              icon: Icons.folder_outlined,
                              title: n,
                              subtitle: null,
                              isCurrent: currentFolderName?.toLowerCase() ==
                                  n.toLowerCase(),
                              onTap: () => Navigator.pop(
                                  context, _PickResult.adHoc(n)),
                            ),
                        ],
                      ),
              ),
              const Divider(),
              _tile(
                context: context,
                icon: Icons.create_new_folder_outlined,
                title: 'New folder…',
                subtitle: null,
                isCurrent: false,
                onTap: () =>
                    Navigator.pop(context, const _PickResult.createNew()),
              ),
              if (allowNone)
                _tile(
                  context: context,
                  icon: Icons.folder_off_outlined,
                  title: 'No folder',
                  subtitle: null,
                  isCurrent: false,
                  onTap: () =>
                      Navigator.pop(context, const _PickResult.none()),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
      ],
    );
  }

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String? subtitle,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(children: [
          Icon(icon,
              color: isCurrent ? AppColors.iris : c.inkSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.titleMedium?.copyWith(
                        color: isCurrent ? AppColors.iris : c.ink)),
                if (subtitle != null)
                  Text(subtitle,
                      style:
                          text.labelSmall?.copyWith(color: c.inkTertiary)),
              ],
            ),
          ),
          if (isCurrent)
            const Icon(Icons.check_rounded,
                color: AppColors.iris, size: 20),
        ]),
      ),
    );
  }
}
