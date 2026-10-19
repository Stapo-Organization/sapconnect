import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';
import 'action_feed_item_card.dart';
import 'all_clear_card.dart';

/// "ما يحتاج انتباهك الآن" — the server-ranked, de-duplicated priority feed as
/// ONE Shopify section: title with a count, rows separated by hairlines, and
/// a "view all" link when there is more. Empty → a calm all-clear row.
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
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    final hasMore = groups.length > maxVisible && onViewAll != null;
    final visible = groups.take(maxVisible).toList();
    return AppSection(
      title: context.tr('action_center_title'),
      count: groups.length,
      actionLabel: hasMore ? context.tr('view_all') : null,
      onAction: hasMore ? onViewAll : null,
      dividerIndent: 64,
      children: groups.isEmpty
          ? const [AllClearCard(asCard: false)]
          : [
              for (var i = 0; i < visible.length; i++)
                ActionFeedItemCard(
                  item: visible[i].lead,
                  repeat: visible[i].count,
                  onTap: () => onItemTap(visible[i].lead),
                ).animate().fadeIn(delay: (40 * i).ms, duration: 220.ms),
            ],
    );
  }
}
