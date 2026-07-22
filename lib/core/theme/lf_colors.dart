import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Brightness-aware design tokens. Widgets read `context.lf`.
class LfColors extends ThemeExtension<LfColors> {
  const LfColors({
    required this.canvas, required this.surface, required this.surfaceSunken,
    required this.hairline, required this.ink, required this.inkSecondary,
    required this.inkTertiary,
  });

  final Color canvas, surface, surfaceSunken, hairline, ink, inkSecondary, inkTertiary;

  static const light = LfColors(
    canvas: AppColors.canvas, surface: AppColors.surface,
    surfaceSunken: AppColors.surfaceSunken, hairline: AppColors.hairline,
    ink: AppColors.ink, inkSecondary: AppColors.inkSecondary,
    inkTertiary: AppColors.inkTertiary,
  );

  /// Deep charcoal dark theme.
  static const dark = LfColors(
    canvas: Color(0xFF131316), surface: Color(0xFF1C1C21),
    surfaceSunken: Color(0xFF26262C), hairline: Color(0xFF2E2E36),
    ink: Color(0xFFF2F2F5), inkSecondary: Color(0xFFA9A9B2),
    inkTertiary: Color(0xFF74747E),
  );

  /// Soft tinted background for a semantic color, per brightness.
  Color soft(Color c, Color lightSoft) =>
      ink.computeLuminance() > 0.5 ? c.withValues(alpha: 0.16) : lightSoft;

  @override
  LfColors copyWith({Color? canvas, Color? surface, Color? surfaceSunken,
      Color? hairline, Color? ink, Color? inkSecondary, Color? inkTertiary}) =>
      LfColors(
        canvas: canvas ?? this.canvas, surface: surface ?? this.surface,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        hairline: hairline ?? this.hairline, ink: ink ?? this.ink,
        inkSecondary: inkSecondary ?? this.inkSecondary,
        inkTertiary: inkTertiary ?? this.inkTertiary,
      );

  @override
  LfColors lerp(LfColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LfColors(
      canvas: l(canvas, other.canvas), surface: l(surface, other.surface),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      hairline: l(hairline, other.hairline), ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkTertiary: l(inkTertiary, other.inkTertiary),
    );
  }
}

extension LfColorsX on BuildContext {
  LfColors get lf => Theme.of(this).extension<LfColors>()!;
}
