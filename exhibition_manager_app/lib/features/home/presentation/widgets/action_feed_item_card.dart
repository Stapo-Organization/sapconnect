import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';

/// One prioritised item in the Action Center, as a Shopify resource row: a
/// quiet icon box, server title/subtitle, and a status badge that carries the
/// urgency (late / due today / ×n). Tapping routes to the feature screen.
class ActionFeedItemCard extends StatelessWidget {
  final HomeFeedItem item;
  final VoidCallback onTap;

  /// How many items of the same type+title this row stands for. When > 1 the
  /// row shows a "{n} overdue" count badge instead of a single status badge.
  final int repeat;

  const ActionFeedItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.repeat = 1,
  });

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      trailing: _trailing(context),
      onTap: onTap,
    );
  }

  Widget _trailing(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final badge = _badge(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null) ...[badge, const SizedBox(width: 4)],
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
          showDot: false,
        );
      case 'overdue_cycle':
        return StatusBadge(
          label: context.tr('feed_overdue'),
          color: AppColors.error,
          showDot: false,
        );
      case 'due_quality':
        return StatusBadge(
          label: context.tr('feed_due_today_f'),
          color: AppColors.warning,
          showDot: false,
        );
      default:
        return null;
    }
  }
}
