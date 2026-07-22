import 'package:flutter/material.dart';
import '../constants/app_radii.dart';
import '../theme/lf_colors.dart';

class LfSkeleton extends StatefulWidget {
  const LfSkeleton({super.key, this.width, this.height = 16, this.radius});
  const LfSkeleton.circle({super.key, double size = 40})
      : width = size, height = size, radius = size;

  final double? width;
  final double height;
  final double? radius;

  @override
  State<LfSkeleton> createState() => _LfSkeletonState();
}

class _LfSkeletonState extends State<LfSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lf = context.lf;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius ?? AppRadii.sm),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0), end: Alignment(0 + 2 * t, 0),
              colors: [lf.surfaceSunken, lf.hairline, lf.surfaceSunken],
            ),
          ),
        );
      },
    );
  }
}
