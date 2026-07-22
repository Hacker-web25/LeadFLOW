import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_avatar.dart';
import '../../../core/widgets/lf_pressable.dart';
import '../../../core/widgets/lf_search_field.dart';
import 'widgets/activity_section.dart';
import 'widgets/followups_section.dart';
import 'widgets/quick_filter_row.dart';
import 'widgets/recent_leads_section.dart';
import 'widgets/stats_row.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final user = ref.watch(authUserStreamProvider).valueOrNull;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.split(' ').first
        : (user?.email.split('@').first ?? 'there');
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.x4, AppSpacing.screenH, 110),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_greeting()}, $name', style: text.bodyLarge),
                  const SizedBox(height: 2),
                  Text(AppConfig.appName, style: text.displaySmall),
                ]),
              ),
              _IconAction(
                icon: Icons.notifications_none_rounded,
                showDot: true,
                onTap: () => context.push(Routes.notifications),
              ),
              const SizedBox(width: AppSpacing.x2),
              LfPressable(
                onTap: () => context.push(Routes.profile),
                child: LfAvatar(name, size: 42),
              ),
            ]),
            const SizedBox(height: AppSpacing.x5),
            LfSearchField(readOnly: true, onTap: () => context.go(Routes.search)),
            const SizedBox(height: AppSpacing.x4),
            const QuickFilterRow(),
            const SizedBox(height: AppSpacing.x5),
            const StatsRow(),
            const SizedBox(height: AppSpacing.x8),
            const FollowUpsSection(),
            const SizedBox(height: AppSpacing.x8),
            const RecentLeadsSection(),
            const SizedBox(height: AppSpacing.x8),
            const ActivitySection(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    return LfPressable(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: c.surface, shape: BoxShape.circle,
          border: Border.all(color: c.hairline),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: 22, color: c.ink),
          if (showDot)
            Positioned(
              top: 10, right: 10,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.iris, shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
