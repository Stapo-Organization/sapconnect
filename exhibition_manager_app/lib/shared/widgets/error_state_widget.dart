import 'package:flutter/material.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/widgets/animated_icons.dart';
import '../../core/design_system/widgets/app_button.dart';
import '../../core/localization/app_localizations.dart';

/// Error state with retry («المتجر»): the same shape as [EmptyState] — a soft
/// critical-tinted disc, a calm title, one line of help and a secondary
/// "retry" button. Errors inform; they don't shout.
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
        child: PopIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowIconChip(
                icon: icon,
                color: AppColors.error,
                size: 64,
                iconSize: 30,
                borderRadius: BorderRadius.circular(32),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                title ?? context.tr('error_title'),
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  subtitle ?? context.tr('error_subtitle'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: context.tr('retry'),
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  expand: false,
                  variant: AppButtonVariant.tonal,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
