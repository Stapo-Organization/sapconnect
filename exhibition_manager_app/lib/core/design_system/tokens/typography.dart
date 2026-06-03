import 'package:flutter/material.dart';

/// Muntajat Exhibition Manager — Design Tokens: Typography
///
/// Uses Cairo font for Arabic-first UI with fallback to system fonts.
///
/// All styles use [TextLeadingDistribution.even] so the extra line-height
/// (`height` multiplier) is split evenly above and below the glyph. This keeps
/// single-line labels visually centered inside fixed-height pills/tabs/buttons
/// (otherwise Cairo glyphs float toward the top of their line box) without
/// changing line-height totals or paragraph wrapping.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Cairo';

  static const TextLeadingDistribution _evenLeading =
      TextLeadingDistribution.even;

  // ─── Display (hero numbers, points, big stats) ─────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    leadingDistribution: _evenLeading,
  );

  // ─── Headline ──────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    leadingDistribution: _evenLeading,
  );

  // ─── Title ─────────────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  // ─── Body ──────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: _evenLeading,
  );

  // ─── Label ─────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );
}
