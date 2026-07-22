import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../../../core/theme/lf_colors.dart';

/// Notifications, derived from live pipeline state (due follow-ups first).
/// Push delivery arrives with the notifications milestone; the screen and
/// data flow are already real.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUps = ref.watch(followUpsStreamProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: followUps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LfErrorState(
          message: 'Notifications could not be loaded.',
          onRetry: () => ref.invalidate(followUpsStreamProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const LfEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing needs you',
              message:
                  'Follow-up reminders and lead alerts will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
            itemBuilder: (_, i) {
              final f = items[i];
              final overdue = f.dueAt.isBefore(DateTime.now());
              return LfCard(
                onTap: () => context.push(Routes.leadDetailPath(f.leadId)),
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: overdue
                            ? context.lf.soft(AppColors.hot, AppColors.hotSoft)
                            : AppColors.iris.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        overdue
                            ? Icons.alarm_rounded
                            : Icons.event_available_rounded,
                        size: 19,
                        color: overdue ? AppColors.hot : AppColors.iris,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overdue
                                ? 'Overdue follow-up · ${f.leadName}'
                                : 'Follow-up · ${f.leadName}',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            f.note ?? f.companyName,
                            style: text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(DateFormat('d MMM, h:mm a').format(f.dueAt),
                        style: text.labelSmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
