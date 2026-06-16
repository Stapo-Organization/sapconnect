import 'package:flutter/material.dart';
import 'colors.dart';

/// Per-section colour identity.
///
/// Every screen keeps the royal-blue structure; its **domain accent** colours
/// the icon chips, active tab states, section headers and primary actions — so
/// each area of the app has a clear sense of place instead of one flat blue.
///
/// The five bottom-nav domains resolve to five distinct hues (blue, teal,
/// emerald, gold, indigo); Quality (amber) and Zooboxi (urgency crimson) only
/// appear on their own pushed pages and the Home launcher cards, so no two
/// adjacent surfaces ever clash.
enum AppDomain { home, transfers, counting, quality, achievements, profile, zooboxi, promotions, showroomPulse, productSearch, admin, stockDistribution, containerTracking }

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
      case AppDomain.zooboxi:
        return const Color(0xFFE11D48); // crimson — urgency / express orders
      case AppDomain.promotions:
        return const Color(0xFF9333EA); // violet-magenta — promotions / spotlight
      case AppDomain.showroomPulse:
        return AppColors.primary; // royal blue — the dashboard "brain" of the app
      case AppDomain.productSearch:
        return const Color(0xFF4C5FD5); // cobalt-indigo — the product catalogue / lookup
      case AppDomain.admin:
        return const Color(0xFF334155); // slate — the owner's command centre
      case AppDomain.stockDistribution:
        return const Color(0xFF0D9488); // deep teal — smart redistribution
      case AppDomain.containerTracking:
        return const Color(0xFF0C6E9C); // ocean blue — sea-freight / containers
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
      case AppDomain.zooboxi:
        return const Color(0xFFBE123C); // deep crimson
      case AppDomain.promotions:
        return const Color(0xFF7E22CE); // deep violet
      case AppDomain.showroomPulse:
        return AppColors.primaryDark;
      case AppDomain.productSearch:
        return const Color(0xFF3A4BB0); // deep cobalt
      case AppDomain.admin:
        return const Color(0xFF1E293B); // deep slate
      case AppDomain.stockDistribution:
        return const Color(0xFF0F766E); // deep teal
      case AppDomain.containerTracking:
        return const Color(0xFF084E70); // deep ocean blue
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
