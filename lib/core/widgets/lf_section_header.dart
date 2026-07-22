import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/lf_colors.dart';

class LfSectionHeader extends StatelessWidget {
  const LfSectionHeader(this.label, {super.key, this.actionLabel, this.onAction});

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(children: [
        Text(label.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(color: context.lf.inkTertiary)),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.iris, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}
