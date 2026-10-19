import 'package:flutter/material.dart';

/// Muntajat HUB — Design Tokens: Border Radius («المتجر»).
///
/// Three working sizes: 8 (chips, badges, small boxes), 12 (cards, buttons,
/// inputs), 16 (sheets, dialogs). The older names stay as aliases so existing
/// call sites land on one of the three instead of eight different curves.
class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 12;
  static const double xl = 12;
  static const double xxl = 16;
  static const double xxxl = 16;
  static const double full = 999;

  static BorderRadius get borderXs => BorderRadius.circular(xs);
  static BorderRadius get borderSm => BorderRadius.circular(sm);
  static BorderRadius get borderMd => BorderRadius.circular(md);
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  static BorderRadius get borderXxl => BorderRadius.circular(xxl);
  static BorderRadius get borderXxxl => BorderRadius.circular(xxxl);
  static BorderRadius get borderFull => BorderRadius.circular(full);
}
