import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import 'package:exhibition_manager_app/features/retail_dashboard/presentation/widgets/leaderboard_row.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/presentation/widgets/sales_profit_chart.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/presentation/pages/branch_detail_page.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/pages/promotions_page.dart';
import 'package:exhibition_manager_app/features/stock_distribution/presentation/pages/stock_distribution_page.dart';
import 'package:exhibition_manager_app/features/container_tracking/presentation/pages/container_tracking_page.dart';
import 'package:exhibition_manager_app/features/quality_control/presentation/pages/quality_admin_page.dart';

import '../owner_theme.dart';
import '../controllers/owner_command_controller.dart';
import '../../data/models/owner_command_models.dart';
import '../widgets/owner_hero.dart';
import '../widgets/owner_kpi_tile.dart';
import '../widgets/decision_queue_card.dart';

/// «القيادة» — صفحة مركز القيادة للمالك. تجمع نبض الشبكة، طابور القرارات،
/// المخطّط، ترتيب الفروع، وشرائط الشحن/المحرّك على هوية سليت داكنة. تستهلك
/// [OwnerCommandController] الذي يجمّع المصادر بالتوازي.
class OwnerCommandPage extends StatefulWidget {
  final User user;

  /// يُستدعى عند ضغط خلية قناة في الهيرو — الشِل يفتح تبويب الأداء عليها.
  final void Function(String channel)? onOpenPerformance;

  const OwnerCommandPage({super.key, required this.user, this.onOpenPerformance});

  @override
  State<OwnerCommandPage> createState() => _OwnerCommandPageState();
}

class _OwnerCommandPageState extends State<OwnerCommandPage> {
  final OwnerCommandController _c = OwnerCommandController();

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) => _c.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: OwnerTheme.bg,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final s = _c.data;
            return RefreshIndicator(
              onRefresh: _c.refresh,
              color: OwnerTheme.accent,
              backgroundColor: OwnerTheme.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  OwnerHero(
                    userName: widget.user.name,
                    snapshot: s,
                    loading: _c.loading,
                    onOpenPerformance: widget.onOpenPerformance,
                  ),
                  if (_c.loading && s == null)
                    _loading()
                  else if (_c.hasError && s == null)
                    _error(context)
                  else if (s != null)
                    ..._content(context, s),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── حالات التحميل/الخطأ بهوية سليت (بدل الويدجتس الفاتحة) ───
  Widget _loading() => Padding(
        padding: EdgeInsets.only(top: AppSpacing.huge),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation<Color>(OwnerTheme.accent),
          ),
        ),
      );

  Widget _error(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, 0),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: OwnerTheme.textMuted),
            const SizedBox(height: AppSpacing.base),
            Text(
              context.tr('owner_load_error'),
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(color: OwnerTheme.textHi),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _c.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.tr('retry')),
              style: OutlinedButton.styleFrom(
                foregroundColor: OwnerTheme.textHi,
                side: BorderSide(color: OwnerTheme.hairline),
              ),
            ),
          ],
        ),
      );

  // ─── المحتوى الكامل ───
  List<Widget> _content(BuildContext context, OwnerCommandSnapshot s) {
    return [
      const SizedBox(height: AppSpacing.lg),

      // نبض الشبكة (روافع المال) — يظهر فقط حين تتوفّر بيانات البيع.
      if (s.retailOk) ...[
        _sectionTitle(context, 'owner_section_pulse'),
        _kpiRow(context, s),
      ],

      // ما ينتظر قرارك
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.lg, AppSpacing.base, 0),
        child: DecisionQueueCard(items: _queueItems(s)),
      ),

      // المبيعات والأرباح
      if (s.retailOk && s.trend.points.isNotEmpty) ...[
        _sectionTitle(context, 'owner_section_trend'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: SalesProfitChart(trend: s.trend, salesColor: AppDomain.admin.accent),
        ),
      ],

      // ترتيب الفروع
      if (s.retailOk && s.topBranches.isNotEmpty) ...[
        _sectionTitle(context, 'owner_section_leaderboard'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            children: [
              for (var i = 0; i < s.topBranches.length; i++)
                LeaderboardRow(
                  branch: s.topBranches[i],
                  rank: i + 1,
                  maxNet: s.maxNet,
                  onTap: () => _open(BranchDetailPage(
                    warehouseCode: s.topBranches[i].code,
                    initialName: s.topBranches[i].name,
                  )),
                ).animate().fadeIn(duration: 280.ms, delay: (i * 45).ms).slideY(begin: 0.12, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ],

      // الشحن + المحرّك
      _sectionTitle(context, 'owner_section_ops'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          children: [
            _engineStrip(context, s),
            const SizedBox(height: AppSpacing.sm),
            _containerStrip(context, s),
          ],
        ),
      ),
    ];
  }

  Widget _sectionTitle(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: OwnerTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.tr(key),
              style: AppTypography.titleSmall.copyWith(
                color: OwnerTheme.textHi,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  // ─── صفّ نبض الشبكة ───
  Widget _kpiRow(BuildContext context, OwnerCommandSnapshot s) {
    final tiles = <Widget>[
      OwnerKpiTile(
        icon: Icons.savings_rounded,
        label: context.tr('owner_kpi_profit'),
        value: sarCompact(s.totalProfit),
        accent: OwnerTheme.positive,
      ),
      OwnerKpiTile(
        icon: Icons.percent_rounded,
        label: context.tr('owner_kpi_margin'),
        value: s.marginPct != null ? pctLabel(s.marginPct!) : '—',
        accent: OwnerTheme.info,
      ),
      OwnerKpiTile(
        icon: Icons.trending_down_rounded,
        label: context.tr('owner_kpi_bleeding'),
        value: sarCompact(s.totalBleeding),
        accent: OwnerTheme.danger,
      ),
      OwnerKpiTile(
        icon: Icons.lock_clock_rounded,
        label: context.tr('owner_kpi_trapped'),
        value: sarCompact(s.totalTrapped),
        accent: OwnerTheme.caution,
      ),
      OwnerKpiTile(
        icon: Icons.storefront_rounded,
        label: context.tr('owner_kpi_branches'),
        value: '${s.branchesCount}',
        accent: OwnerTheme.accent,
      ),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  // ─── عناصر طابور القرارات (تُربط بصفحاتها) ───
  List<DecisionItem> _queueItems(OwnerCommandSnapshot s) => [
        DecisionItem(
          icon: Icons.campaign_rounded,
          color: AppDomain.promotions.accent,
          title: context.tr('owner_queue_promos'),
          count: s.promosPending,
          ok: s.promosOk,
          onTap: () => _open(const PromotionsPage(initialStatus: 'suggested')),
        ),
        DecisionItem(
          icon: Icons.hub_rounded,
          color: AppDomain.stockDistribution.accent,
          title: context.tr('owner_queue_distribution'),
          count: s.distributionPending,
          ok: s.distributionOk,
          onTap: () => _open(const StockDistributionPage()),
        ),
        DecisionItem(
          icon: Icons.fact_check_rounded,
          color: AppDomain.quality.accent,
          title: context.tr('owner_queue_quality'),
          count: s.qualityOverdue,
          ok: s.qualityOk,
          onTap: () => _open(const QualityAdminPage()),
        ),
        DecisionItem(
          icon: Icons.directions_boat_rounded,
          color: AppDomain.containerTracking.accent,
          title: context.tr('owner_queue_containers'),
          count: s.containersDelayed,
          ok: s.containersOk,
          onTap: () => _open(const ContainerTrackingPage()),
        ),
      ];

  // ─── شريط محرّك التوزيع ───
  Widget _engineStrip(BuildContext context, OwnerCommandSnapshot s) {
    final running = s.engine?.running ?? false;
    final pending = s.distributionPending;
    final statusColor = running ? OwnerTheme.positive : OwnerTheme.textMuted;
    return Pressable(
      onTap: () => _open(const StockDistributionPage()),
      borderRadius: AppRadius.borderLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: OwnerTheme.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: OwnerTheme.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppDomain.stockDistribution.accent.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(Icons.hub_rounded, size: 18, color: AppDomain.stockDistribution.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('owner_section_engine'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: OwnerTheme.textHi,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${context.tr(running ? 'owner_engine_running' : 'owner_engine_idle')} · $pending ${context.tr('owner_engine_pending')}',
                    style: AppTypography.labelSmall.copyWith(color: OwnerTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_left_rounded, size: 20, color: OwnerTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── شريط تنبيهات الشحن ───
  Widget _containerStrip(BuildContext context, OwnerCommandSnapshot s) {
    final attention = s.containersDelayed;
    final nearest = s.containers?.nearestLabel;
    return Pressable(
      onTap: () => _open(const ContainerTrackingPage()),
      borderRadius: AppRadius.borderLg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: OwnerTheme.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: OwnerTheme.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppDomain.containerTracking.accent.withValues(alpha: 0.18),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(Icons.directions_boat_rounded, size: 18, color: AppDomain.containerTracking.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('owner_section_containers'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: OwnerTheme.textHi,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nearest != null && nearest.isNotEmpty
                        ? nearest
                        : (attention > 0
                            ? '$attention ${context.tr('owner_containers_attention')}'
                            : context.tr('owner_containers_clear')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(color: OwnerTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (attention > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: OwnerTheme.caution.withValues(alpha: 0.20),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  '$attention',
                  style: AppTypography.labelMedium.copyWith(
                    color: OwnerTheme.caution,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_left_rounded, size: 20, color: OwnerTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
