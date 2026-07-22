import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lf_colors.dart';

abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(LfColors c) {
    return GoogleFonts.interTextTheme().copyWith(
      displaySmall: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600,
          letterSpacing: -0.6, color: c.ink, height: 1.15),
      headlineSmall: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600,
          letterSpacing: -0.4, color: c.ink, height: 1.2),
      titleLarge: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600,
          letterSpacing: -0.2, color: c.ink),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
          letterSpacing: -0.1, color: c.ink),
      bodyLarge: GoogleFonts.inter(fontSize: 15, height: 1.45, color: c.ink),
      bodyMedium: GoogleFonts.inter(fontSize: 13.5, height: 1.45, color: c.inkSecondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.8, color: c.inkTertiary),
    );
  }

  static TextStyle stat = GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700,
      letterSpacing: -0.5, fontFeatures: _tabular);

  static TextStyle eyebrow = GoogleFonts.inter(fontSize: 11,
      fontWeight: FontWeight.w600, letterSpacing: 0.9);
}
