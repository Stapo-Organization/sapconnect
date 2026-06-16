import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';

/// One prioritised item in the Action Center. Domain-coloured icon chip, a
/// leading urgency band, title/subtitle from the server, and a contextual
/// status badge. Tapping routes to the relevant feature screen.
class ActionFeedItemCard extends StatelessWidget {
  final HomeFeedItem item;
  final VoidCallback onTap;

  /// How many items of the same type+title this row stands for. When > 1 the
  /// card shows a "{n} overdue" count pill instead of a single status badge.
  final int repeat;

  const ActionFeedItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.repeat = 1,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.appDomain.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.base),
        borderColor: item.bandColor.withValues(alpha: 0.25),
        child: Row(
          children: [
            // Leading urgency band.
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: item.bandColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Domain icon chip.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.appDomain.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            // Title + subtitle.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _trailing(context),
          ],
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final badge = _badge(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null) ...[badge, const SizedBox(width: AppSpacing.xs)],
        Icon(
          isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
          size: 20,
        ),
      ],
    );
  }

  /// A short status pill for overdue / due-today items (the eye-catcher).
  Widget? _badge(BuildContext context) {
    // Folded row: show how many of this task are stacked behind it.
    if (repeat > 1) {
      return StatusBadge(
        label: context.tr('feed_count_overdue').replaceAll('{n}', '$repeat'),
        color: AppColors.error,
        icon: Icons.layers_rounded,
        showDot: false,
      );
    }
    switch (item.type) {
      // Quality items are مهمة (feminine) → use the feminine form so the badge
      // agrees with the server-side title ("… — متأخرة").
      case 'overdue_quality':
        return StatusBadge(
          label: context.tr('feed_overdue_f'),
          color: AppColors.error,
          icon: Icons.warning_amber_rounded,
          showDot: false,
        );
      case 'overdue_cycle':
        return StatusBadge(
          label: context.tr('feed_overdue'),
          color: AppColors.error,
          icon: Icons.warning_amber_rounded,
          showDot: false,
        );
      case 'due_quality':
        return StatusBadge(
          label: context.tr('feed_due_today_f'),
          color: AppColors.warning,
          icon: Icons.event_available_rounded,
          showDot: false,
        );
      default:
        return null;
    }
  }
}
