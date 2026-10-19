import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Summary header for dashboard-style screens («المتجر»): a near-black panel
/// (graphite in dark mode) with white type — the one dark surface Shopify uses
/// for headline numbers. Optional leading, trailing actions and a [child]
/// (e.g. a stats row) below the title.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? child;
  /// Defaults to the mode-aware [AppColors.heroGradient] when null (resolved at
  /// build time — can't be a const default now that the token is a getter).
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.child,
    this.gradient,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.base,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Pushed (not a tab root) and no custom leading → a back button, since
    // this header replaces the app bar.
    final canPop = Navigator.of(context).canPop();
    final lead = leading ??
        (canPop
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const BackButtonIcon(),
                color: Colors.white,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : null);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (lead != null) ...[lead, const SizedBox(width: AppSpacing.sm)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headlineSmall.copyWith(color: Colors.white),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!],
            ],
          ),
        ),
      ),
    );
  }
}
