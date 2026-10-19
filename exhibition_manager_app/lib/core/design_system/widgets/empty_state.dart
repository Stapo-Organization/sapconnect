import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'animated_icons.dart';
import 'app_button.dart';
import 'status_badge.dart';

/// Empty state («المتجر»): a quiet grey disc with the icon, a clear title in
/// full ink, one line of help, and an optional action — the Shopify empty
/// state. One shape for every list in the app.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  /// Only a semantic colour (e.g. error) tints the disc; otherwise it is grey.
  final Color? color;

  /// A custom action widget (used instead of [actionLabel]/[onAction]).
  final Widget? trailing;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // The app accent is "no meaning" → neutral disc; only semantic colours tint.
    final color = (this.color == AppColors.primary || this.color == AppColors.primaryDark) ? null : this.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
        child: PopIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // White disc with a hairline: reads on the grey canvas and on cards.
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color == null ? AppColors.surface : StatusBadge.fill(color),
                  shape: BoxShape.circle,
                  border: color == null ? Border.all(color: AppColors.border) : null,
                ),
                child: Icon(icon, size: 28, color: color == null ? AppColors.textSecondary : StatusBadge.ink(color)),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(height: AppSpacing.lg),
                trailing!,
              ] else if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
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
