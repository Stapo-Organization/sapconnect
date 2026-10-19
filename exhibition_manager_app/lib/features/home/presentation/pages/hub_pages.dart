import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/stock_transfer/presentation/pages/transfers_list_page.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/pages/counting_sessions_page.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/presentation/pages/zooboxi_orders_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_tasks_page.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:exhibition_manager_app/features/showroom_pulse/presentation/pages/showroom_pulse_page.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/pages/achievements_page.dart';

/// One destination in a hub: icon, title, one-line description, the page.
class HubEntry {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final WidgetBuilder builder;

  const HubEntry(this.icon, this.titleKey, this.subtitleKey, this.builder);
}

/// A tab that gathers several features as Shopify-style rows («المتجر»):
/// a large page title on the canvas, then sections of rows that push the full
/// feature page (with its own back button). Keeps the bottom bar at five tabs.
class HubPage extends StatelessWidget {
  final String titleKey;
  final String subtitleKey;
  final List<(String?, List<HubEntry>)> sections;

  const HubPage({super.key, required this.titleKey, required this.subtitleKey, required this.sections});

  @override
  Widget build(BuildContext context) {
    final visible = sections.where((s) => s.$2.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PageHeader(title: context.tr(titleKey), subtitle: context.tr(subtitleKey)),
          for (final (title, entries) in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppSection(
                title: title == null ? null : context.tr(title),
                dividerIndent: 64,
                children: [
                  for (final e in entries)
                    AppListRow(
                      icon: e.icon,
                      title: context.tr(e.titleKey),
                      subtitle: context.tr(e.subtitleKey),
                      chevron: true,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: e.builder)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// «العمليات» — transfers, counts, express orders, quality, offers.
class OperationsHub extends StatelessWidget {
  final User user;
  const OperationsHub({super.key, required this.user});

  static bool visibleFor(User u) =>
      u.hasFeature(Feature.stockTransfer) ||
      u.hasFeature(Feature.inventoryCounting) ||
      u.hasFeature(Feature.zooboxiOrders) ||
      u.hasFeature(Feature.qualityControl);

  @override
  Widget build(BuildContext context) {
    return HubPage(
      titleKey: 'nav_operations',
      subtitleKey: 'hub_ops_subtitle',
      sections: [
        ('hub_ops_stock', [
          if (user.hasFeature(Feature.stockTransfer))
            HubEntry(Icons.swap_horiz_rounded, 'stock_transfers', 'hub_transfers_sub', (_) => const TransfersListPage()),
          if (user.hasFeature(Feature.inventoryCounting))
            HubEntry(Icons.inventory_2_outlined, 'nav_counting', 'hub_counting_sub',
                (_) => CountingSessionsPage(warehouseCodes: user.warehouseCodes)),
        ]),
        ('hub_ops_orders', [
          if (user.hasFeature(Feature.zooboxiOrders))
            HubEntry(Icons.bolt_rounded, 'zooboxi_urgent_orders', 'hub_zooboxi_sub', (_) => const ZooboxiOrdersPage()),
          if (user.hasFeature(Feature.qualityControl))
            HubEntry(Icons.verified_outlined, 'quality_tasks', 'hub_quality_sub', (_) => const QualityTasksPage()),
          if (user.hasFeature(Feature.promotions) && user.isOwnerExperience)
            HubEntry(Icons.local_offer_outlined, 'promotions', 'hub_promotions_sub', (_) => const PromotionsPage()),
        ]),
      ],
    );
  }
}

/// «الأداء» — showroom health and the user's own achievements.
class PerformanceHub extends StatelessWidget {
  final User user;
  const PerformanceHub({super.key, required this.user});

  static bool visibleFor(User u) => u.hasFeature(Feature.showroomPulse) || u.hasFeature(Feature.gamification);

  @override
  Widget build(BuildContext context) {
    return HubPage(
      titleKey: 'nav_performance',
      subtitleKey: 'hub_perf_subtitle',
      sections: [
        (null, [
          if (user.hasFeature(Feature.showroomPulse))
            HubEntry(Icons.monitor_heart_outlined, 'nav_showroom_pulse', 'hub_pulse_sub', (_) => const ShowroomPulsePage()),
          if (user.hasFeature(Feature.gamification))
            HubEntry(Icons.emoji_events_outlined, 'nav_achievements', 'hub_achievements_sub', (_) => const AchievementsPage()),
        ]),
      ],
    );
  }
}
