import 'package:flutter/material.dart';

/// LeadFlow palette.
///
/// One accent (iris), a cool neutral ramp, and a semantic temperature trio
/// that doubles as the product's visual signature.
abstract final class AppColors {
  // Neutrals
  static const ink = Color(0xFF16161D);        // primary text, primary buttons
  static const inkSecondary = Color(0xFF5C5C66);
  static const inkTertiary = Color(0xFF8E8E99);
  static const canvas = Color(0xFFF7F7F9);     // app background
  static const surface = Color(0xFFFFFFFF);    // cards
  static const surfaceSunken = Color(0xFFF1F1F4);
  static const hairline = Color(0xFFE7E7EC);

  // Accent
  static const iris = Color(0xFF5B5BD6);
  static const irisSoft = Color(0xFFEEEEFB);

  // Lead temperature (semantic + signature)
  static const hot = Color(0xFFE5484D);
  static const hotSoft = Color(0xFFFDEBEC);
  static const warm = Color(0xFFF2930D);
  static const warmSoft = Color(0xFFFDF1E0);
  static const cold = Color(0xFF3E8DE3);
  static const coldSoft = Color(0xFFE9F2FC);

  // Feedback
  static const success = Color(0xFF30A46C);
  static const successSoft = Color(0xFFE6F5EE);
  static const danger = hot;
}
