import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

/// A polished product row shared by the branch-detail money-lever cards, the
/// best-sellers card, and their "view all" pages: a rounded thumbnail, the
/// product name with a light stock/health subtitle, and an accent-colored
/// primary metric. Keeping one tile everywhere makes the three sections read
/// as one consistent, professional system.
class ProductMetricTile extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String value;
  final String valueLabel;
  final Color accent;
  final double? stock; // current stock → "remaining" subtitle
  final String? healthStatus; // shows a colored status chip
  final int? rank; // 1-based rank badge (best-sellers)
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap; // tap → open the product-detail page
  final List<(String, Color)> chips; // extra status chips (e.g. OOS, on-order)

  const ProductMetricTile({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.value,
    required this.valueLabel,
    required this.accent,
    this.stock,
    this.healthStatus,
    this.rank,
    this.padding = const EdgeInsets.symmetric(vertical: 7),
    this.onTap,
    this.chips = const [],
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle(context);
    final row = Row(
      children: [
        if (rank != null) ...[_rankBadge(), const SizedBox(width: AppSpacing.sm)],
        ProductThumb(url: imageUrl, size: 48, accent: accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[const SizedBox(height: 4), subtitle],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTypography.titleSmall.copyWith(color: accent, fontWeight: FontWeight.w800)),
            Text(valueLabel,
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
          ],
        ),
        // A subtle drill-in affordance so the row reads as tappable (RTL-aware).
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ],
    );
    final content = Padding(padding: padding, child: row);
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: content,
      ),
    );
  }

  Widget _rankBadge() {
    final gold = rank == 1;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold ? accent : accent.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Text('$rank',
          style: AppTypography.labelSmall.copyWith(
            color: gold ? Colors.white : accent,
            fontWeight: FontWeight.w800,
          )),
    );
  }

  Widget? _subtitle(BuildContext context) {
    final health = _healthChip(context);
    final showStock = stock != null;
    final extra = chips.map((c) => _chip(c.$1, c.$2)).toList();
    if (!showStock && health == null && extra.isEmpty) return null;
    // Wrap (not Row) so several chips never overflow — they flow to a second line.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showStock)
          Text('${context.tr('rd_remaining')} ${unitsLabel(stock!)}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
        ?health,
        ...extra,
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: AppRadius.borderFull),
        child: Text(label,
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
      );

  Widget? _healthChip(BuildContext context) {
    if (healthStatus == null || healthStatus!.isEmpty) return null;
    final (color, key) = switch (healthStatus) {
      'stockout' => (AppColors.error, 'health_stockout'),
      'starved' => (AppColors.error, 'health_starved'),
      'low' => (AppColors.warning, 'health_low'),
      'overstock' => (AppColors.warning, 'health_overstock'),
      'dead' => (AppColors.textSecondary, 'health_dead'),
      _ => (AppColors.textTertiary, ''),
    };
    if (key.isEmpty) return null;
    return _chip(context.tr(key), color);
  }
}
