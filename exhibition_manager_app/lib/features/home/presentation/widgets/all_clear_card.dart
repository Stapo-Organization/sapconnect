import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Celebratory empty state for the Action Center — shown when nothing is
/// urgent. A calm gold gradient + checkmark, "كل شيء تمام 🎉".
class AllClearCard extends StatelessWidget {
  const AllClearCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.lg,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
      ),
      borderColor: AppColors.warning.withValues(alpha: 0.20),
      child: Row(
        children: [
          FloatingIcon(
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('all_clear_title'),
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('all_clear_subtitle'),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
