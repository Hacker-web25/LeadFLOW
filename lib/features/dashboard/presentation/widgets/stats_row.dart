import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/lf_colors.dart';
import '../../../../core/widgets/lf_card.dart';
import '../../../../core/widgets/lf_skeleton.dart';
import '../../../leads/presentation/providers/leads_providers.dart';

class StatsRow extends ConsumerWidget {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(leadStatsProvider);
    return stats.when(
      loading: () => Row(children: [
        for (var i = 0; i < 4; i++) ...[
          const Expanded(child: LfSkeleton(height: 116, radius: 20)),
          if (i < 3) const SizedBox(width: AppSpacing.x2),
        ],
      ]),
      error: (e, _) => const SizedBox.shrink(),
      data: (s) => Row(children: [
        _StatTile(value: s.today, label: 'Today', accent: AppColors.iris,
            icon: Icons.person_add_alt_outlined,
            delta: s.today > 0 ? '+${s.today} new' : null),
        const SizedBox(width: AppSpacing.x2),
        _StatTile(value: s.hot, label: 'Hot', accent: AppColors.hot,
            icon: Icons.local_fire_department_outlined,
            delta: s.hot > 0 ? '+${s.hot} new' : null),
        const SizedBox(width: AppSpacing.x2),
        _StatTile(value: s.followUpsDueToday, label: 'Due today',
            accent: AppColors.warm, icon: Icons.event_outlined),
        const SizedBox(width: AppSpacing.x2),
        _StatTile(value: s.total, label: 'Total leads', accent: AppColors.cold,
            icon: Icons.folder_outlined),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label,
      required this.accent, required this.icon, this.delta});

  final int value;
  final String label;
  final Color accent;
  final IconData icon;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: LfCard(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.x4, horizontal: AppSpacing.x3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text('$value', style: AppTypography.stat.copyWith(color: c.ink)),
          const SizedBox(height: 2),
          Text(label, style: text.bodyMedium?.copyWith(fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text('$delta ↑',
                style: text.labelSmall?.copyWith(
                    color: accent, letterSpacing: 0.2, fontSize: 10.5)),
          ],
        ]),
      ),
    );
  }
}
