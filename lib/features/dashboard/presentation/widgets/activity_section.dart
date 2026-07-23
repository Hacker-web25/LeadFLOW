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

/// Recent activity — compact by default (3 rows), "See all" expands.
class ActivitySection extends ConsumerStatefulWidget {
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
  ConsumerState<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<ActivitySection> {
  bool _expanded = false;
  static const _collapsedCount = 3;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(recentActivityProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LfSectionHeader('Recent activity'),
        activity.when(
          loading: () => const LfSkeleton(height: 96, radius: 16),
          error: (e, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return LfCard(
                child: Text('Activity will appear here as you work leads.',
                    style: text.bodyMedium),
              );
            }
            final visible = _expanded
                ? items
                : items.take(_collapsedCount).toList();
            final hasMore = items.length > _collapsedCount;
            return LfCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x1),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (final a in visible) ...[
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                        child: Row(
                          children: [
                            Icon(ActivitySection.iconFor(a.type),
                                size: 17, color: context.lf.inkTertiary),
                            const SizedBox(width: AppSpacing.x3),
                            Expanded(
                              child: Text(a.summary,
                                  style: text.bodyMedium
                                      ?.copyWith(color: context.lf.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Text(a.occurredAt.relativeLabel,
                                style: text.labelSmall),
                          ],
                        ),
                      ),
                      if (a != visible.last)
                        Divider(
                            height: 1,
                            color:
                                context.lf.hairline.withValues(alpha: 0.6)),
                    ],
                    if (hasMore) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.x2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_expanded
                                  ? 'Show less'
                                  : 'See all ${items.length}',
                                  style: text.labelLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                              const SizedBox(width: 4),
                              Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
