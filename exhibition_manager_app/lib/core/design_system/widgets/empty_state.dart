import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'animated_icons.dart';
import 'app_button.dart';

/// Friendly empty state with a floating icon inside soft halo rings, title,
/// subtitle and optional CTA. Consistent across all list screens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة طافية داخل هالتين متحدتَي المركز — تدخل بنبضة ثم تطفو بهدوء.
            PopIn(
              child: SizedBox(
                width: 152,
                height: 152,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 152,
                      height: 152,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.withValues(alpha: 0.07), width: 1.5),
                      ),
                    ),
                    Container(
                      width: 122,
                      height: 122,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.withValues(alpha: 0.12), width: 1.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.withValues(alpha: 0.13), c.withValues(alpha: 0.04)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: FloatingIcon(
                        child: Icon(icon, size: 48, color: c.withValues(alpha: 0.60)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                icon: Icons.add_rounded,
                color: c,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
