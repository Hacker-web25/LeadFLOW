import 'package:flutter/widgets.dart';

/// Corner language: soft, consistent, never mixed ad-hoc.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static final BorderRadius card = BorderRadius.circular(lg);
  static final BorderRadius control = BorderRadius.circular(md);
  static final BorderRadius chip = BorderRadius.circular(pill);
}
