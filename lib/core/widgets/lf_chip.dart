import 'package:flutter/material.dart';
import '../constants/app_durations.dart';
import '../constants/app_radii.dart';
import '../theme/lf_colors.dart';
import 'lf_pressable.dart';

class LfChoiceChip extends StatelessWidget {
  const LfChoiceChip({super.key, required this.label, required this.selected,
      required this.onTap, this.leading});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final onSel = Theme.of(context).colorScheme.onPrimary;
    final sel = Theme.of(context).colorScheme.primary;
    return LfPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? sel : c.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: selected ? sel : c.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13.5, color: selected ? onSel : c.ink)),
          ],
        ),
      ),
    );
  }
}
