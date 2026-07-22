import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Initials avatar with deterministic soft background per name.
class LfAvatar extends StatelessWidget {
  const LfAvatar(this.name, {super.key, this.size = 44});

  final String name;
  final double size;

  static const _palette = [AppColors.iris, AppColors.cold, AppColors.warm, AppColors.success];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : name.isEmpty ? '?' : name[0];
    final fg = _palette[name.hashCode.abs() % _palette.length];
    final bg = fg.withValues(alpha: 0.16);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}
