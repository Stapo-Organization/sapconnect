import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';
import 'package:exhibition_manager_app/features/home/presentation/widgets/action_feed_item_card.dart';
import 'package:exhibition_manager_app/features/home/presentation/widgets/all_clear_card.dart';

/// The full "needs your attention" list — the overflow behind the home Action
/// Center's "view all". Rows route through the same handler the home screen
/// uses; tapping pops back first so detail pages / tab switches happen from the
/// home context, not stacked on top of this page.
class ActionCenterPage extends StatelessWidget {
  final List<FeedGroup> groups;
  final void Function(HomeFeedItem item) onItemTap;

  const ActionCenterPage({super.key, required this.groups, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('action_center_title')),
        body: groups.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AllClearCard(),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  return ActionFeedItemCard(
                    item: g.lead,
                    repeat: g.count,
                    onTap: () {
                      Navigator.of(context).pop();
                      onItemTap(g.lead);
                    },
                  ).animate().fadeIn(delay: (40 * i).ms, duration: 300.ms).slideY(
                        begin: 0.06,
                        end: 0,
                        curve: Curves.easeOut,
                      );
                },
              ),
      ),
    );
  }
}
