import 'package:flutter/material.dart';
import 'colors.dart';

/// Sections of the app.
///
/// Since the «المتجر» redesign (2026-10-08) every section shares ONE accent —
/// the near-black action colour in light mode, the Muntajat blue in dark — and
/// sections are told apart by their icons. The enum and its getters stay so
/// existing call sites keep compiling; they simply all resolve to the same
/// calm palette. Meaning (late / done / failed) still comes from the semantic
/// colours in [AppColors], never from a section hue.
enum AppDomain { home, transfers, counting, quality, achievements, profile, zooboxi, promotions, showroomPulse, productSearch, admin, stockDistribution, containerTracking, operations, performance }

extension AppDomainPalette on AppDomain {
  /// Accent for chrome: selected tabs, section icons, primary actions.
  Color get accent => AppColors.primary;

  /// Darker shade for text / icons that need contrast on white.
  Color get accentDark => AppColors.primaryDark;

  /// Neutral tint behind section icons (Shopify-style grey icon box).
  Color get soft => AppColors.secondary;

  /// The dark summary panel (white type on top) — near-black in light mode,
  /// graphite in dark. Same for every section: no decorative hues.
  LinearGradient get gradient => AppColors.heroGradient;
}
