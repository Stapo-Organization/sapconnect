import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';
import 'action_feed_item_card.dart';
import 'all_clear_card.dart';

/// The smart top section: "ما يحتاج انتباهك الآن". Renders the server-ranked,
/// de-duplicated priority feed (staggered in) or the celebratory all-clear card
/// when empty.
class ActionCenter extends StatelessWidget {
  final List<FeedGroup> groups;
  final void Function(HomeFeedItem item) onItemTap;

  /// Tapped when there are more alerts than [maxVisible] — opens the full list.
  final VoidCallback? onViewAll;

  /// How many alerts to surface on the home screen; the rest live behind
  /// "view all".
  final int maxVisible;

  const ActionCenter({
    super.key,
    required this.groups,
    required this.onItemTap,
    this.onViewAll,
    this.maxVisible = 2,
  });

  @override
  Widget build(BuildContext context) {
    final hasMore = groups.length > maxVisible && onViewAll != null;
    final visible = groups.take(maxVisible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            WiggleIcon(
              child: Icon(Icons.priority_high_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.tr('action_center_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (groups.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${groups.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (hasMore) ...[
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('view_all'),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      AppLocalizations.isArabic
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (groups.isEmpty)
          const AllClearCard()
        else
          for (var i = 0; i < visible.length; i++)
            ActionFeedItemCard(
              item: visible[i].lead,
              repeat: visible[i].count,
              onTap: () => onItemTap(visible[i].lead),
            ).animate().fadeIn(delay: (60 * i).ms, duration: 350.ms).slideY(
                  begin: 0.08,
                  end: 0,
                  curve: Curves.easeOut,
                ),
      ],
    );
  }
}
