import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/lf_card.dart';
import '../../../../core/widgets/lf_section_header.dart';
import '../../../../core/widgets/lf_skeleton.dart';
import '../../../leads/domain/lead.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../../core/theme/lf_colors.dart';

/// Recent activity as a compact timeline inside one card.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  static IconData iconFor(ActivityType t) => switch (t) {
        ActivityType.scan => Icons.document_scanner_outlined,
        ActivityType.note => Icons.sticky_note_2_outlined,
        ActivityType.call => Icons.call_outlined,
        ActivityType.email => Icons.mail_outline_rounded,
        ActivityType.meeting => Icons.event_outlined,
        ActivityType.statusChange => Icons.swap_horiz_rounded,
        ActivityType.followUpDone => Icons.check_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(recentActivityProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LfSectionHeader('Recent activity'),
        activity.when(
          loading: () => const LfSkeleton(height: 160, radius: 16),
          error: (e, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return LfCard(
                child: Text('Activity will appear here as you work leads.',
                    style: text.bodyMedium),
              );
            }
            return LfCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
              child: Column(
                children: [
                  for (final a in items) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
                      child: Row(
                        children: [
                          Icon(iconFor(a.type), size: 18, color: context.lf.inkTertiary),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: Text(a.summary,
                                style: text.bodyMedium?.copyWith(color: context.lf.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Text(a.occurredAt.relativeLabel, style: text.labelSmall),
                        ],
                      ),
                    ),
                    if (a != items.last) const Divider(),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
