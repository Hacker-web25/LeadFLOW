import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_radii.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'lf_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, LfColors.light);
  static ThemeData dark() => _build(Brightness.dark, LfColors.dark);

  static ThemeData _build(Brightness b, LfColors c) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.iris, brightness: b)
        .copyWith(
      primary: b == Brightness.light ? AppColors.ink : Colors.white,
      onPrimary: b == Brightness.light ? Colors.white : const Color(0xFF16161D),
      secondary: AppColors.iris,
      surface: c.canvas,
      surfaceContainerLowest: c.surface,
      outlineVariant: c.hairline,
      error: AppColors.danger,
    );
    final text = AppTypography.textTheme(c);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.canvas,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: c.ink,
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle:
            b == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: c.hairline),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface.withValues(alpha: b == Brightness.light ? 0.85 : 0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: AppRadii.control, borderSide: BorderSide(color: c.hairline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.control, borderSide: BorderSide(color: c.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.control,
            borderSide: const BorderSide(color: AppColors.iris, width: 1.5)),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkTertiary),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b == Brightness.light ? AppColors.ink : c.surfaceSunken,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
      ),
    );
  }

  static List<BoxShadow> softShadow(LfColors c) => [
        BoxShadow(
          color: Colors.black.withValues(
              alpha: c.ink.computeLuminance() > 0.5 ? 0.25 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
