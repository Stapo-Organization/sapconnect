import 'package:flutter/material.dart';

/// Muntajat HUB — Design Tokens: Typography («المتجر», Shopify-calm).
///
/// One face: IBM Plex Sans Arabic, bundled at its real weights 400/500/600/700
/// — nothing asks for 800/900, which the engine would fake. Codes (items,
/// shelves, barcodes) use IBM Plex Mono via [mono]/[monoSmall].
///
/// Arabic is cursive: any letterSpacing pulls the joins apart, so every style
/// keeps it at 0. Numbers that line up (stats, quantities) use tabular digits.
///
/// All styles use [TextLeadingDistribution.even] so the extra line-height is
/// split evenly above and below the glyph, keeping single-line labels centred
/// inside fixed-height pills/tabs/buttons.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'IBMPlexSansArabic';
  static const String monoFamily = 'IBMPlexMono';

  /// The Saudi Riyal symbol (U+E900, PUA) lives only in the SaudiRiyal font,
  /// so every style falls back to it for that one glyph.
  static const List<String> fontFamilyFallback = ['SaudiRiyal'];

  static const TextLeadingDistribution _evenLeading = TextLeadingDistribution.even;
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ─── Display (hero numbers) ────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    fontFeatures: _tabular,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: _tabular,
    leadingDistribution: _evenLeading,
  );

  // ─── Headline (page titles) ────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.35,
    leadingDistribution: _evenLeading,
  );

  // ─── Title (card and section headings) ─────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  // ─── Body ──────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    leadingDistribution: _evenLeading,
  );

  // ─── Label (buttons, chips, badges, captions) ──────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  // ─── Mono (codes: P17300055, W12-R3, RUH010, barcodes) ─────
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: [fontFamily, 'SaudiRiyal'],
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: [fontFamily, 'SaudiRiyal'],
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    leadingDistribution: _evenLeading,
  );

  /// Quantities and money inside rows/tables: same face, tabular digits.
  static const TextStyle numeric = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: _tabular,
    leadingDistribution: _evenLeading,
  );
}
