import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../../core/widgets/lf_skeleton.dart';
import '../domain/pending_action.dart';
import 'actions_providers.dart';

/// Renders the pending-action checklist on Lead Detail — voice-note
/// suggestions, plus anything the user added manually.
class ActionsSection extends ConsumerWidget {
  const ActionsSection({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(pendingActionsProvider(leadId));
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: LfSectionHeader('Pending actions')),
          TextButton.icon(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: () => _showAdd(context, ref),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('Add'),
          ),
        ]),
        actionsAsync.when(
          loading: () => const LfSkeleton(height: 88, radius: 20),
          error: (_, __) => LfCard(
            child: Text("Couldn't load actions.",
                style: text.bodyMedium),
          ),
          data: (all) {
            final pending = all
                .where((a) => a.status == PendingActionStatus.pending)
                .toList();
            final done = all
                .where((a) => a.status == PendingActionStatus.done)
                .toList();

            if (all.isEmpty) {
              return LfCard(
                child: Text(
                  'Nothing to do yet. Record a voice note — anything the '
                  'AI hears like "call him tomorrow" or "send WhatsApp" '
                  'lands here.',
                  style: text.bodyMedium,
                ),
              );
            }

            return LfCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
              child: Column(children: [
                for (final a in pending)
                  _ActionRow(action: a, leadId: leadId),
                if (done.isNotEmpty) ...[
                  if (pending.isNotEmpty)
                    Divider(color: context.lf.hairline),
                  for (final a in done)
                    _ActionRow(action: a, leadId: leadId, dimmed: true),
                ],
              ]),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAdd(BuildContext context, WidgetRef ref) async {
    PendingActionKind kind = PendingActionKind.call;
    final descCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setInner) => AlertDialog(
          title: const Text('New action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<PendingActionKind>(
                value: kind,
                items: [
                  for (final k in PendingActionKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setInner(() => kind = v ?? kind),
                decoration: const InputDecoration(labelText: 'Kind'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(hintText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final desc = descCtl.text.trim();
    if (desc.isEmpty) return;
    await ref
        .read(actionRepositoryProvider)
        .createOne(leadId: leadId, kind: kind, description: desc);
    ref.invalidate(pendingActionsProvider(leadId));
    ref.invalidate(pendingCountsProvider);
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.action,
    required this.leadId,
    this.dimmed = false,
  });

  final PendingAction action;
  final String leadId;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lf;
    final text = Theme.of(context).textTheme;
    final due = action.dueAt;
    final overdue = due != null &&
        action.status == PendingActionStatus.pending &&
        due.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        _CheckButton(
          value: action.status == PendingActionStatus.done,
          onChanged: (v) async {
            await ref
                .read(actionRepositoryProvider)
                .markDone(action.id, done: v);
            ref.invalidate(pendingActionsProvider(leadId));
            ref.invalidate(pendingCountsProvider);
          },
        ),
        const SizedBox(width: AppSpacing.x3),
        _KindIcon(kind: action.kind, dimmed: dimmed),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.description,
                style: text.bodyLarge?.copyWith(
                  color: dimmed ? c.inkTertiary : c.ink,
                  decoration: dimmed ? TextDecoration.lineThrough : null,
                ),
              ),
              if (due != null)
                Text(
                  DateFormat('d MMM, h:mm a').format(due),
                  style: text.labelSmall?.copyWith(
                      color: overdue ? AppColors.hot : c.inkTertiary),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: c.inkTertiary),
          onPressed: () async {
            await ref.read(actionRepositoryProvider).delete(action.id);
            ref.invalidate(pendingActionsProvider(leadId));
            ref.invalidate(pendingCountsProvider);
          },
        ),
      ]),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    return InkWell(
      onTap: () => onChanged(!value),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: value ? AppColors.iris : Colors.transparent,
            border: Border.all(
                color: value ? AppColors.iris : c.hairline, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind, required this.dimmed});
  final PendingActionKind kind;
  final bool dimmed;

  IconData get _icon => switch (kind) {
        PendingActionKind.call => Icons.call_outlined,
        PendingActionKind.email => Icons.mail_outline_rounded,
        PendingActionKind.whatsapp => Icons.chat_bubble_outline_rounded,
        PendingActionKind.sms => Icons.sms_outlined,
        PendingActionKind.meeting => Icons.event_outlined,
        PendingActionKind.other => Icons.flag_outlined,
      };

  Color _color(BuildContext context) => switch (kind) {
        PendingActionKind.call => const Color(0xFF34C77B),
        PendingActionKind.email => const Color(0xFF5B8CFF),
        PendingActionKind.whatsapp => const Color(0xFF25D366),
        PendingActionKind.sms => const Color(0xFF8B5CF6),
        PendingActionKind.meeting => const Color(0xFFF59E0B),
        PendingActionKind.other => context.lf.inkSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final baseColor = _color(context);
    final tint = dimmed ? baseColor.withValues(alpha: 0.5) : baseColor;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, size: 17, color: tint),
    );
  }
}

/// Small compact pill for the lead-list card: shows kind icons for the
/// first N pending actions plus a "+M" tail. Silent when there are none.
class LeadActionPill extends ConsumerWidget {
  const LeadActionPill({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(pendingCountsProvider).valueOrNull ??
        const <String, int>{};
    final n = counts[leadId] ?? 0;
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.iris.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 12, color: AppColors.iris),
            const SizedBox(width: 4),
            Text('$n to do',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.iris, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
