import 'package:flutter/material.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/radius.dart';
import '../../core/localization/app_localizations.dart';

/// Reusable error state widget with retry capability.
///
/// Shows a friendly illustration (icon), title, subtitle, and retry button.
/// Use this instead of silently hiding loading states.
class ErrorStateWidget extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.error.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? context.tr('error_title'),
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle ?? context.tr('error_subtitle'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(
                    context.tr('retry'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
