import 'package:flutter/material.dart';
import '../constants/app_durations.dart';
import '../constants/app_radii.dart';
import '../theme/lf_colors.dart';

class LfSegmented<T> extends StatelessWidget {
  const LfSegmented({super.key, required this.options, required this.labelOf,
      required this.value, required this.onChanged});

  final List<T> options;
  final String Function(T) labelOf;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final text = Theme.of(context).textTheme;
    final index = value == null ? -1 : options.indexOf(value as T);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: AppRadii.control),
      child: LayoutBuilder(builder: (context, constraints) {
        final segW = constraints.maxWidth / options.length;
        return Stack(children: [
          if (index >= 0)
            AnimatedPositioned(
              duration: AppMotion.base, curve: AppMotion.enter,
              left: segW * index, width: segW, top: 0, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md - 3),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6, offset: const Offset(0, 1))],
                ),
              ),
            ),
          Row(children: [
            for (final option in options)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(option),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: text.labelLarge!.copyWith(fontSize: 13.5,
                          color: option == value ? c.ink : c.inkSecondary),
                      child: Text(labelOf(option)),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
