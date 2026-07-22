import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_avatar.dart';
import '../../../core/widgets/lf_card.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../domain/scan_flow_controller.dart';

/// Shown right after a card is scanned + saved. The card is already in
/// Supabase — everything here is optional enrichment. Exhibition speed:
/// one tap dismisses, one tap starts a voice note.
class PostScanScreen extends ConsumerWidget {
  const PostScanScreen({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadAsync = ref.watch(leadProvider(leadId));
    final text = Theme.of(context).textTheme;

    void done() {
      ref.read(scanFlowProvider.notifier).reset();
      context.go(Routes.dashboard);
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: done, child: const Text('Done'))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.x2),
              // Success confirmation
              Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.iris, size: 28),
                const SizedBox(width: AppSpacing.x3),
                Expanded(child: Text('Card saved', style: text.headlineSmall)),
              ]),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'You can edit any detail later from the lead. Add more now?',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x5),

              // Lead identity chip
              leadAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (lead) => LfCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
                  child: Row(children: [
                    LfAvatar(lead.contact.fullName, size: 40),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lead.contact.fullName,
                                style: text.titleMedium,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              lead.companyName == '—'
                                  ? (lead.contact.designation ?? '')
                                  : lead.companyName,
                              style: text.bodyMedium
                                  ?.copyWith(color: context.lf.inkTertiary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ]),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push(Routes.leadDetailPath(leadId)),
                      child: const Text('Open'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.x6),

              // Primary action — voice note
              _BigAction(
                icon: Icons.mic_rounded,
                title: 'Add voice note',
                subtitle:
                    'Speak everything — needs, budget, next steps. AI structures it.',
                accent: true,
                onTap: () => context.push('${Routes.voiceNote}?leadId=$leadId'),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Secondary — questionnaire
              _BigAction(
                icon: Icons.checklist_rounded,
                title: 'Run questionnaire',
                subtitle: 'Optional. 7 quick taps to qualify the lead.',
                onTap: () => context.push(Routes.scanQuestionnaire),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: done,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: accent
          ? AppColors.iris
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
                color: accent
                    ? Colors.transparent
                    : context.lf.hairline),
          ),
          child: Row(children: [
            Icon(icon,
                color: accent ? Colors.white : context.lf.ink, size: 26),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleMedium?.copyWith(
                            color: accent ? Colors.white : context.lf.ink,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: text.bodySmall?.copyWith(
                            color: accent
                                ? Colors.white.withValues(alpha: 0.85)
                                : context.lf.inkTertiary)),
                  ]),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: accent ? Colors.white : context.lf.inkTertiary,
                size: 20),
          ]),
        ),
      ),
    );
  }
}
