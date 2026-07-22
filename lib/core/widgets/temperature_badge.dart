import 'package:flutter/material.dart';
import '../../features/leads/domain/lead.dart';
import '../constants/app_radii.dart';
import '../theme/app_colors.dart';
import '../theme/lf_colors.dart';

class TemperatureBadge extends StatelessWidget {
  const TemperatureBadge(this.temperature, {super.key, this.dense = false});

  final LeadTemperature? temperature;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = temperature;
    if (t == null) return const SizedBox.shrink();
    final (color, lightSoft) = switch (t) {
      LeadTemperature.hot => (AppColors.hot, AppColors.hotSoft),
      LeadTemperature.warm => (AppColors.warm, AppColors.warmSoft),
      LeadTemperature.cold => (AppColors.cold, AppColors.coldSoft),
    };
    final dot = Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)],
      ),
    );
    if (dense) return dot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: context.lf.soft(color, lightSoft), borderRadius: AppRadii.chip),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        dot,
        const SizedBox(width: 5),
        Text(t.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color, letterSpacing: 0.4, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
