import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/lf_section_header.dart';
import '../../../../core/widgets/lf_skeleton.dart';
import '../../../../core/widgets/lf_state_views.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../leads/presentation/widgets/lead_card.dart';

/// The latest three captures — most of what an exhibitor checks between
/// conversations.
class RecentLeadsSection extends ConsumerWidget {
  const RecentLeadsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(leadsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LfSectionHeader('Recent leads',
            actionLabel: 'View all', onAction: () => context.go(Routes.leads)),
        leads.when(
          loading: () => Column(children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.x2),
                child: LfSkeleton(height: 80, radius: 16),
              ),
          ]),
          // Errors during first-connect are common (realtime handshake,
          // brief auth restore). The stream itself retries silently — show
          // the empty state instead of a jarring error card.
          error: (_, __) => LfEmptyState(
            icon: Icons.badge_outlined,
            title: 'No leads yet',
            message: 'Scan your first business card and it will appear here.',
            actionLabel: 'Scan a card',
            onAction: () => context.push(Routes.scan),
          ),
          data: (all) {
            if (all.isEmpty) {
              return LfEmptyState(
                icon: Icons.badge_outlined,
                title: 'No leads yet',
                message: 'Scan your first business card and it will appear here instantly.',
                actionLabel: 'Scan a card',
                onAction: () => context.push(Routes.scan),
              );
            }
            final recent = all.take(3).toList();
            return Column(
              children: [
                for (final lead in recent) ...[
                  LeadCard(lead: lead),
                  if (lead != recent.last) const SizedBox(height: AppSpacing.x2),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
