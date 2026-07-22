import 'package:flutter/animation.dart';

/// Motion tokens. Subtle only: 150–250ms, decelerating.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;

  /// Press-down scale for tappable surfaces.
  static const double pressScale = 0.97;
}
