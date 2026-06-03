import 'package:flutter/material.dart';
import 'colors.dart';

/// Per-section colour identity.
///
/// Every screen keeps the royal-blue structure; its **domain accent** colours
/// the icon chips, active tab states, section headers and primary actions — so
/// each area of the app has a clear sense of place instead of one flat blue.
///
/// The five bottom-nav domains resolve to five distinct hues (blue, teal,
/// emerald, gold, indigo); Quality (amber) only appears on its own pushed page
/// and the Home launcher card, so no two adjacent surfaces ever clash.
enum AppDomain { home, transfers, counting, quality, achievements, profile }

extension AppDomainPalette on AppDomain {
  /// Primary accent — fills, active states, icon glyphs on soft chips.
  Color get accent {
    switch (this) {
      case AppDomain.home:
        return AppColors.primary;
      case AppDomain.transfers:
        return const Color(0xFF0E9BB0); // teal-cyan — movement / logistics
      case AppDomain.counting:
        return const Color(0xFF0E9F6E); // emerald — inventory
      case AppDomain.quality:
        return const Color(0xFFE0A012); // amber — polish / inspection
      case AppDomain.achievements:
        return AppColors.accentDark; // gold — points
      case AppDomain.profile:
        return const Color(0xFF6D5DD3); // indigo-violet — account
    }
  }

  /// Darker shade for text / icons that need contrast on white.
  Color get accentDark {
    switch (this) {
      case AppDomain.home:
        return AppColors.primaryDark;
      case AppDomain.transfers:
        return const Color(0xFF0A7C8C);
      case AppDomain.counting:
        return const Color(0xFF0B7D57);
      case AppDomain.quality:
        return const Color(0xFFB87908);
      case AppDomain.achievements:
        return AppColors.accentDark;
      case AppDomain.profile:
        return const Color(0xFF564BB0);
    }
  }

  /// Soft ~12% tint for icon chips and section backgrounds.
  Color get soft => accent.withValues(alpha: 0.12);

  /// Section gradient (accent → darker) for heroes / highlights.
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [accent, accentDark],
      );
}
