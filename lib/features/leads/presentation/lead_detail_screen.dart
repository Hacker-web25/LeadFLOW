import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/lf_avatar.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_chip.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../../core/widgets/lf_segmented.dart';
import '../../../core/widgets/lf_skeleton.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../../core/widgets/platform_image.dart';
import '../../../core/widgets/temperature_badge.dart';
import '../../dashboard/presentation/widgets/activity_section.dart' show ActivitySection;
import '../../exhibitions/data/exhibition_controller.dart';
import '../../exhibitions/domain/exhibition.dart';
import '../../voice_note/presentation/voice_notes_section.dart';
import '../domain/lead.dart';
import 'providers/leads_providers.dart';

// Uses the shared cardImageUrlProvider (see providers/leads_providers.dart)
// so lists + detail share one cached signed URL per lead.

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadProvider(leadId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead'),
        actions: [
          lead.maybeWhen(
            data: (l) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) async {
                if (v == 'edit') {
                  await _EditSheet.show(context, l);
                } else if (v == 'move') {
                  await _MoveToFolderSheet.show(context, l);
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete lead?'),
                      content: Text(
                          'This permanently removes ${l.contact.fullName} and all related activity.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.hot))),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await ref.read(leadRepositoryProvider).deleteLead(l.id);
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'move', child: Text('Move to folder…')),
                PopupMenuItem(value: 'delete',
                    child: Text('Delete', style: TextStyle(color: AppColors.hot))),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lead.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenH),
          child: Column(children: [
            LfSkeleton(height: 160, radius: 20),
            SizedBox(height: AppSpacing.x3),
            LfSkeleton(height: 200, radius: 20),
          ]),
        ),
        error: (e, _) => LfErrorState(
          message: 'This lead could not be loaded.',
          onRetry: () => ref.invalidate(leadProvider(leadId)),
        ),
        data: (lead) => _Body(lead: lead),
      ),
      floatingActionButton: lead.maybeWhen(
        data: (l) => FloatingActionButton.extended(
          onPressed: () => context.push('${Routes.voiceNote}?leadId=${l.id}'),
          backgroundColor: AppColors.iris,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Voice note'),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final activity = ref.watch(leadActivityProvider(lead.id));
    final image = ref.watch(cardImageUrlProvider(lead.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, 110),
      children: [
        // Business card image
        image.maybeWhen(
          data: (url) => url == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                  child: ClipRRect(
                    borderRadius: AppRadii.card,
                    child: AspectRatio(
                      aspectRatio: 85.6 / 54,
                      child: PlatformImage(path: url),
                    ),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),

        LfCard(
          child: Column(children: [
            Row(children: [
              LfAvatar(lead.contact.fullName, size: 56),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lead.contact.fullName, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    [if (lead.contact.designation != null) lead.contact.designation!,
                        lead.companyName].join(' · '),
                    style: text.bodyMedium,
                  ),
                ]),
              ),
              TemperatureBadge(lead.temperature),
            ]),
            if (lead.eventName != null) ...[
              const SizedBox(height: AppSpacing.x4),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 15,
                    color: context.lf.inkTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${lead.eventName} · ${DateFormat('d MMM, h:mm a').format(lead.capturedAt)}',
                    style: text.labelSmall?.copyWith(letterSpacing: 0.2),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.x6),

        const LfSectionHeader('Qualification'),
        LfCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
          child: Column(children: [
            _InfoRow('Timeline', lead.timeline?.label),
            _InfoRow('Customer type', lead.customerType?.label),
            _InfoRow('Decision maker', _yesNo(lead.isDecisionMaker)),
            _InfoRow('Export requirement', _yesNo(lead.exportRequirement)),
            _InfoRow('Sales team required', _yesNo(lead.salesTeamRequired), last: true),
          ]),
        ),
        const SizedBox(height: AppSpacing.x6),

        const LfSectionHeader('Contact'),
        LfCard(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
          child: Column(children: [
            _InfoRow('Mobile', lead.contact.phone),
            _InfoRow('Phone', lead.contact.altPhone),
            _InfoRow('Email', lead.contact.email),
            _InfoRow('Website', lead.company?.website),
            _InfoRow('Company', lead.company?.name),
            _InfoRow('Location',
                [lead.company?.city, lead.company?.country]
                    .whereType<String>().join(', '),
                last: true),
          ]),
        ),

        if (lead.additionalNotes?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.x6),
          const LfSectionHeader('Notes'),
          LfCard(child: Text(lead.additionalNotes!, style: text.bodyLarge)),
        ],

        const SizedBox(height: AppSpacing.x6),
        VoiceNotesSection(leadId: lead.id),

        const SizedBox(height: AppSpacing.x6),
        const LfSectionHeader('Timeline'),
        activity.when(
          loading: () => const LfSkeleton(height: 120, radius: 20),
          error: (e, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return LfCard(
                  child: Text('No activity yet for this lead.', style: text.bodyMedium));
            }
            return LfCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
              child: Column(children: [
                for (final a in items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
                    child: Row(children: [
                      Icon(ActivitySection.iconFor(a.type), size: 18,
                          color: context.lf.inkTertiary),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(child: Text(a.summary,
                          style: text.bodyMedium?.copyWith(color: context.lf.ink))),
                      Text(a.occurredAt.relativeLabel, style: text.labelSmall),
                    ]),
                  ),
                  if (a != items.last) const Divider(),
                ],
              ]),
            );
          },
        ),
      ],
    );
  }

  static String? _yesNo(bool? v) =>
      switch (v) { null => null, true => 'Yes', false => 'No' };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});

  final String label;
  final String? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: text.bodyMedium)),
          Expanded(
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              style: text.bodyLarge?.copyWith(
                  color: value == null ? c.inkTertiary : c.ink,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ]),
      ),
      if (!last) const Divider(),
    ]);
  }
}

/// Edit qualification + notes in a sheet; saves through the repository.
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.lead});

  final Lead lead;

  static Future<void> show(BuildContext context, Lead lead) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _EditSheet(lead: lead),
      );

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late Lead _draft = widget.lead;
  late final _notes = TextEditingController(text: widget.lead.additionalNotes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _draft.copyWith(additionalNotes: _notes.text.trim());
    final r = await ref.read(leadRepositoryProvider).updateLead(updated);
    if (!mounted) return;
    r.when(
      ok: (_) => Navigator.pop(context),
      err: (f) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x6),
            children: [
              Text('Edit lead', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.x5),
              _group('Lead temperature',
                  LfSegmented<LeadTemperature>(
                    options: LeadTemperature.values,
                    labelOf: (t) => t.label,
                    value: _draft.temperature,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(temperature: v)),
                  )),
              _group('Timeline', Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in RequirementTimeline.values)
                  LfChoiceChip(label: t.label, selected: _draft.timeline == t,
                      onTap: () =>
                          setState(() => _draft = _draft.copyWith(timeline: t))),
              ])),
              _group('Customer type', Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in CustomerType.values)
                  LfChoiceChip(label: t.label, selected: _draft.customerType == t,
                      onTap: () =>
                          setState(() => _draft = _draft.copyWith(customerType: t))),
              ])),
              _group('Decision maker', _bool(_draft.isDecisionMaker,
                  (v) => setState(() => _draft = _draft.copyWith(isDecisionMaker: v)))),
              _group('Export requirement', _bool(_draft.exportRequirement,
                  (v) => setState(() => _draft = _draft.copyWith(exportRequirement: v)))),
              _group('Sales team required', _bool(_draft.salesTeamRequired,
                  (v) => setState(() => _draft = _draft.copyWith(salesTeamRequired: v)))),
              _group('Notes', TextField(
                controller: _notes, maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              )),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.x2, AppSpacing.screenH, AppSpacing.x4),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bool(bool? v, ValueChanged<bool> onChanged) => LfSegmented<bool>(
      options: const [true, false],
      labelOf: (b) => b ? 'Yes' : 'No',
      value: v, onChanged: onChanged);

  Widget _group(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LfSectionHeader(label),
          child,
        ]),
      );
}

/// Move an existing lead into a different folder — or into no folder.
/// Handles the "I forgot to pick a folder before scanning" case.
class _MoveToFolderSheet extends ConsumerStatefulWidget {
  const _MoveToFolderSheet({required this.lead});
  final Lead lead;

  static Future<void> show(BuildContext context, Lead lead) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _MoveToFolderSheet(lead: lead),
      );

  @override
  ConsumerState<_MoveToFolderSheet> createState() =>
      _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends ConsumerState<_MoveToFolderSheet> {
  final _newFolderCtl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newFolderCtl.dispose();
    super.dispose();
  }

  Future<void> _move(String? name) async {
    setState(() => _busy = true);
    // If the user typed a brand-new name, make sure a folder row exists.
    if (name != null && name.isNotEmpty) {
      final createResult =
          await ref.read(exhibitionRepositoryProvider).create(name);
      createResult.when(
        ok: (_) {},
        err: (_) {/* proceed anyway — event_name is text */},
      );
    }
    final r = await ref.read(leadRepositoryProvider).setLeadFolder(
        leadId: widget.lead.id, folderName: name);
    ref.invalidate(leadProvider(widget.lead.id));
    ref.invalidate(leadsStreamProvider);
    ref.invalidate(exhibitionsProvider);
    if (!mounted) return;
    r.when(
      ok: (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(name == null || name.isEmpty
                ? 'Lead removed from folder.'
                : 'Lead moved to $name.')));
      },
      err: (f) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final exhibitionsAsync = ref.watch(exhibitionsProvider);
    final knownNames = ref.watch(knownExhibitionsProvider);
    final currentFolder = widget.lead.eventName?.trim();
    final c = context.lf;

    final exhibitions = exhibitionsAsync.valueOrNull ?? const <Exhibition>[];
    final displayedNames = <String>{
      for (final e in exhibitions) e.name.toLowerCase(),
    };
    final adHoc = knownNames
        .where((n) => !displayedNames.contains(n.toLowerCase()))
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
              Text('Move to folder', style: text.titleLarge),
              const SizedBox(height: AppSpacing.x2),
              Text('Currently in: ${currentFolder ?? "no folder"}',
                  style: text.bodyMedium?.copyWith(color: c.inkTertiary)),
              const SizedBox(height: AppSpacing.x5),

              // New folder
              const LfSectionHeader('New folder'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderCtl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. IPPE Atlanta 2026',
                      prefixIcon: Icon(Icons.create_new_folder_outlined),
                    ),
                    onSubmitted: (_) => _move(_newFolderCtl.text.trim()),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _move(_newFolderCtl.text.trim()),
                  child: const Text('Create & Move'),
                ),
              ]),
              const SizedBox(height: AppSpacing.x5),

              // Existing folders
              if (exhibitions.isNotEmpty || adHoc.isNotEmpty) ...[
                const LfSectionHeader('Existing folders'),
                for (final e in exhibitions)
                  _MoveTile(
                    name: e.name,
                    isCurrent: currentFolder?.toLowerCase() ==
                        e.name.toLowerCase(),
                    onTap: _busy ? null : () => _move(e.name),
                  ),
                for (final n in adHoc)
                  _MoveTile(
                    name: n,
                    isCurrent: currentFolder?.toLowerCase() == n.toLowerCase(),
                    onTap: _busy ? null : () => _move(n),
                  ),
                const SizedBox(height: AppSpacing.x3),
              ],

              if (currentFolder != null)
                TextButton.icon(
                  onPressed: _busy ? null : () => _move(null),
                  icon: const Icon(Icons.folder_off_outlined),
                  label: const Text('Remove from folder'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({
    required this.name,
    required this.isCurrent,
    required this.onTap,
  });
  final String name;
  final bool isCurrent;
  final VoidCallback? onTap;

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
              Icon(Icons.folder_rounded,
                  color: isCurrent ? AppColors.iris : c.inkSecondary),
              const SizedBox(width: AppSpacing.x3),
              Expanded(child: Text(name, style: text.titleMedium)),
              if (isCurrent)
                const Icon(Icons.check_rounded, color: AppColors.iris),
            ]),
          ),
        ),
      ),
    );
  }
}
