import 'package:flutter/material.dart';

import '../constants/app_durations.dart';

/// The one tappable-surface primitive: scales to [AppMotion.pressScale]
/// on press. Every card, chip and tile routes through this so press
/// feedback is identical across the app.
class LfPressable extends StatefulWidget {
  const LfPressable({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<LfPressable> createState() => _LfPressableState();
}

class _LfPressableState extends State<LfPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}
