import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/supabase/app_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/lf_card.dart';
import '../../../../core/widgets/lf_section_header.dart';
import '../../../../core/widgets/lf_skeleton.dart';
import '../../../follow_ups/domain/follow_up.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../../core/theme/lf_colors.dart';

/// Today's follow-ups with one-tap completion.
class FollowUpsSection extends ConsumerWidget {
  const FollowUpsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUps = ref.watch(todaysFollowUpsProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LfSectionHeader("Today's follow-ups"),
        followUps.when(
          loading: () => const LfSkeleton(height: 72, radius: 16),
          error: (e, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return LfCard(
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded, color: AppColors.iris, size: 22),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('No follow-ups due today', style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text("Great job! You're all caught up.", style: text.bodyMedium),
                      ]),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final f in items) ...[
                  _FollowUpTile(f),
                  if (f != items.last) const SizedBox(height: AppSpacing.x2),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FollowUpTile extends ConsumerWidget {
  const _FollowUpTile(this.followUp);

  final FollowUp followUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final overdue = followUp.dueAt.isBefore(DateTime.now());

    return LfCard(
      onTap: () => context.push(Routes.leadDetailPath(followUp.leadId)),
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: [
          // Complete
          GestureDetector(
            onTap: () async {
              await ref.read(leadRepositoryProvider).completeFollowUp(followUp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Follow-up with ${followUp.leadName} completed')),
                );
              }
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.lf.hairline, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(followUp.leadName, style: text.titleMedium),
                const SizedBox(height: 1),
                Text(
                  followUp.note ?? followUp.companyName,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            DateFormat.jm().format(followUp.dueAt),
            style: text.labelSmall?.copyWith(
              color: overdue ? AppColors.hot : AppColors.inkTertiary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
