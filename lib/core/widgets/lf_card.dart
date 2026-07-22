import 'package:flutter/material.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/lf_colors.dart';
import 'lf_pressable.dart';

class LfCard extends StatelessWidget {
  const LfCard({super.key, required this.child, this.onTap,
      this.padding = const EdgeInsets.all(AppSpacing.x4), this.elevated = true});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: c.hairline),
        boxShadow: elevated ? AppTheme.softShadow(c) : null,
      ),
      child: child,
    );
    return onTap == null ? card : LfPressable(onTap: onTap, child: card);
  }
}
