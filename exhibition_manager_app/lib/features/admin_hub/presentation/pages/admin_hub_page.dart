import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/core/permissions/app_session.dart';

import 'package:exhibition_manager_app/features/retail_dashboard/presentation/pages/retail_dashboard_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_admin_page.dart';
import 'package:exhibition_manager_app/features/stock_distribution/presentation/pages/stock_distribution_page.dart';
import 'package:exhibition_manager_app/features/container_tracking/presentation/pages/container_tracking_page.dart';

/// Admin Center (لوحة الإدارة) — the Super Admin launcher. One tab that opens
/// onto the owner's tools, instead of crowding the bottom nav bar.
class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final entries = <_HubEntry>[
      if (AppSession.can(Ability.retailDashboardView))
        _HubEntry(
          domain: AppDomain.admin,
          icon: Icons.insights_rounded,
          titleKey: 'admin_retail_dashboard',
          descKey: 'admin_retail_dashboard_desc',
          builder: () => const RetailDashboardPage(),
        ),
      if (AppSession.can(Ability.qualityAdminView))
        _HubEntry(
          domain: AppDomain.quality,
          icon: Icons.checklist_rounded,
          titleKey: 'admin_quality_tasks',
          descKey: 'admin_quality_tasks_desc',
          builder: () => const QualityAdminPage(),
        ),
      if (AppSession.can(Ability.stockDistributionView))
        _HubEntry(
          domain: AppDomain.stockDistribution,
          icon: Icons.auto_awesome_rounded,
          titleKey: 'admin_stock_distribution',
          descKey: 'admin_stock_distribution_desc',
          builder: () => const StockDistributionPage(),
        ),
      if (AppSession.can(Ability.containerTrackingView))
        _HubEntry(
          domain: AppDomain.containerTracking,
          icon: Icons.directions_boat_rounded,
          titleKey: 'admin_container_tracking',
          descKey: 'admin_container_tracking_desc',
          builder: () => const ContainerTrackingPage(),
        ),
    ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                title: context.tr('admin_hub_title'),
                subtitle: context.tr('admin_hub_subtitle'),
                gradient: AppDomain.admin.gradient,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.base),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _card(context, entries[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _HubEntry e) {
    final accent = e.domain.accent;
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => e.builder())),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(gradient: e.domain.gradient, borderRadius: AppRadius.borderLg),
            child: Icon(e.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(e.titleKey), style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(context.tr(e.descKey),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(
            AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _HubEntry {
  final AppDomain domain;
  final IconData icon;
  final String titleKey;
  final String descKey;
  final Widget Function() builder;
  _HubEntry({
    required this.domain,
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.builder,
  });
}
