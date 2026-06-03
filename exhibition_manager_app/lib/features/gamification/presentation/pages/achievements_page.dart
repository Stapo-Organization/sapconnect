import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Achievements / إنجازاتي tab.
///
/// Placeholder shell wired into the navigation now; the full gamification
/// experience (points, level, streak, badges, leaderboard) is implemented in
/// Phase 2 once the backend endpoints are live.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GradientHeader(
              title: context.tr('nav_achievements'),
              subtitle: context.tr('achievements_subtitle'),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.emoji_events_rounded,
                title: context.tr('achievements_soon_title'),
                subtitle: context.tr('achievements_soon_subtitle'),
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
