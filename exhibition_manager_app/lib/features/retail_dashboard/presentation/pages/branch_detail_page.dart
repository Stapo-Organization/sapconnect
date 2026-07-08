import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/retail_models.dart';
import '../../data/retail_dashboard_repository.dart';
import '../widgets/product_metric_tile.dart';
import '../widgets/sales_profit_chart.dart';
import 'branch_items_page.dart';

/// Full drill-down for one exhibition: revenue + trend + best-sellers (all bound
/// to the period filter), then the branch's snapshot vitals, money levers and
/// operations (period-independent). Changing the period reloads only the
/// filter-bound section, so the snapshot cards never flash.
class BranchDetailPage extends StatefulWidget {
  final String warehouseCode;
  final String initialName;
  const BranchDetailPage({super.key, required this.warehouseCode, required this.initialName});

  @override
  State<BranchDetailPage> createState() => _BranchDetailPageState();
}

class _BranchDetailPageState extends State<BranchDetailPage> {
  final RetailDashboardRepository _repo = RetailDashboardRepository();
  BranchDetail? _data;
  bool _loading = true; // first full-page load
  bool _periodLoading = false; // re-fetch triggered by a period change
  bool _hasError = false;
  String _period = 'month';

  static const _periods = ['today', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final r = await _repo.getBranch(widget.warehouseCode, period: _period);
    if (!mounted) return;
    setState(() {
      if (r.success) {
        _data = r.data;
        _hasError = false;
      } else {
        _hasError = _data == null;
      }
      _loading = false;
      _periodLoading = false;
    });
  }

  // Pull-to-refresh: refetch silently (RefreshIndicator shows its own spinner).
  Future<void> _refresh() => _fetch();

  void _setPeriod(String p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _periodLoading = true; // only the period-bound cards go to skeleton
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final accent = AppDomain.admin.accent;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: _data?.name ?? widget.initialName),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxl),
            children: [
              _periodBar(context, accent),
              const SizedBox(height: AppSpacing.base),
              ..._content(context, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodBar(BuildContext context, Color accent) {
    final labels = {
      'today': context.tr('rd_period_today'),
      'week': context.tr('rd_period_week'),
      'month': context.tr('rd_period_month'),
      'year': context.tr('rd_period_year'),
    };
    final idx = _periods.indexOf(_period);
    return AppSegmentedControl(
      activeColor: accent,
      selectedIndex: idx < 0 ? 2 : idx,
      onChanged: (i) => _setPeriod(_periods[i]),
      items: _periods.map((p) => SegmentItem(labels[p]!)).toList(),
    );
  }

  List<Widget> _content(BuildContext context, Color accent) {
    if (_loading) {
      return [const SkeletonCard(height: 120), const SizedBox(height: 12), const SkeletonCard(height: 180)];
    }
    if (_hasError || _data == null) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _fetch))];
    }
    final d = _data!;
    return [
      // ── Filter-bound section (revenue · trend · best-sellers) ──
      if (_periodLoading)
        ..._periodSkeleton()
      else
        ..._periodScoped(context, d, accent),
      // ── Snapshot section (period-independent) ──
      if (d.score != null) ...[_vitalsCard(context, d, accent), const SizedBox(height: AppSpacing.base)],
      _bleedingCard(context, d),
      const SizedBox(height: AppSpacing.base),
      _trappedCard(context, d),
      const SizedBox(height: AppSpacing.base),
      _opsCard(context, d),
    ];
  }

  List<Widget> _periodSkeleton() => const [
        SkeletonCard(height: 150),
        SizedBox(height: AppSpacing.base),
        SkeletonCard(height: 180),
        SizedBox(height: AppSpacing.base),
        SkeletonCard(height: 150),
        SizedBox(height: AppSpacing.base),
      ];

  List<Widget> _periodScoped(BuildContext context, BranchDetail d, Color accent) => [
        _revenueCard(context, d),
        const SizedBox(height: AppSpacing.base),
        if (d.trend.points.isNotEmpty) ...[
          SalesProfitChart(trend: d.trend, salesColor: accent),
          const SizedBox(height: AppSpacing.base),
        ],
        if (d.topProducts.isNotEmpty) ...[_topSellersCard(context, d, accent), const SizedBox(height: AppSpacing.base)],
      ];

  Widget _sectionTitle(String text) =>
      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Text(text, style: AppTypography.titleSmall));

  Widget _revenueCard(BuildContext context, BranchDetail d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.tr('bd_revenue')),
          Row(
            children: [
              _kpi(sarAmount(d.revenue.net), context.tr('rd_net_sales'), AppColors.success),
              _kpi(intGrouped(d.revenue.invoices), context.tr('rd_total_invoices'), AppColors.primary),
              _kpi(sarAmount(d.revenue.aov), context.tr('bd_aov'), AppDomain.admin.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('${context.tr('bd_gross')}: ${sarAmount(d.revenue.gross)}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: AppSpacing.base),
              Text('${context.tr('bd_returns')}: ${sarAmount(d.revenue.returns)}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
            ],
          ),
          if (d.profit.marginPct != null) ...[
            const SizedBox(height: AppSpacing.md),
            _profitStrip(context, d),
          ],
        ],
      ),
    );
  }

  Widget _profitStrip(BuildContext context, BranchDetail d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(Icons.trending_up_rounded, color: AppColors.success, size: 19),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(context.tr(d.profit.estimated ? 'rd_profit' : 'rd_profit_actual'),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                    const Spacer(),
                    Text(sarAmount(d.profit.profit),
                        style: AppTypography.titleSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.success, borderRadius: AppRadius.borderFull),
                      child: Text('${context.tr('rd_margin')} ${d.profit.marginPct!.toStringAsFixed(0)}٪',
                          style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(context.tr(d.profit.estimated ? 'rd_profit_note' : 'rd_profit_note_actual'),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10),
                    maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String value, String label, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      );

  Widget _vitalsCard(BuildContext context, BranchDetail d, Color accent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(context.tr('bd_vitals'))),
              if (d.score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                  child: Text(
                    d.rank != null && d.totalBranches != null
                        ? '${d.score!.toStringAsFixed(0)} · ${d.rank}/${d.totalBranches}'
                        : d.score!.toStringAsFixed(0),
                    style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          ...d.vitals.map((v) => _vitalRow(context, v)),
        ],
      ),
    );
  }

  Widget _vitalRow(BuildContext context, Vital v) {
    final value = v.value;
    final c = value == null
        ? AppColors.textTertiary
        : value >= 80
            ? AppColors.success
            : value >= 60
                ? AppColors.warning
                : AppColors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(context.tr('vital_${v.key}'), style: AppTypography.bodySmall)),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value == null ? 0 : (value / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(value == null ? '—' : '${value.toStringAsFixed(0)}%',
                textAlign: TextAlign.end, style: AppTypography.labelSmall.copyWith(color: c, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Best-sellers (period-scoped) ────────────────────────────
  Widget _topSellersCard(BuildContext context, BranchDetail d, Color accent) {
    return _productSection(
      context: context,
      icon: Icons.local_fire_department_rounded,
      accent: accent,
      titleKey: 'bd_top_products',
      tiles: [
        for (var i = 0; i < d.topProducts.take(4).length; i++)
          ProductMetricTile(
            imageUrl: d.topProducts[i].imageUrl,
            name: d.topProducts[i].name,
            value: unitsLabel(d.topProducts[i].units),
            valueLabel: context.tr('bd_units'),
            accent: accent,
            rank: i + 1,
            onTap: () => openProductDetail(context, d.topProducts[i].itemCode,
                name: d.topProducts[i].name, myWarehouses: [widget.warehouseCode]),
          ),
      ],
      onViewAll: () => _openItems(BranchItemsType.top, d.name),
    );
  }

  // ─── Money levers (snapshot) ─────────────────────────────────
  Widget _bleedingCard(BuildContext context, BranchDetail d) {
    return _productSection(
      context: context,
      icon: Icons.trending_down_rounded,
      accent: AppColors.error,
      titleKey: 'bd_bleeding_title',
      total: d.bleedingTotal > 0 ? sarCompact(d.bleedingTotal) : null,
      tiles: [
        for (final it in d.bleedingItems.take(3))
          ProductMetricTile(
            imageUrl: it.imageUrl,
            name: it.name,
            value: sarCompact(it.primaryValue),
            valueLabel: context.tr('rd_lost_monthly'),
            accent: AppColors.error,
            stock: it.currentStock,
            healthStatus: it.healthStatus,
            chips: [
              it.isOos
                  ? (context.tr('rd_tag_reorder'), AppColors.error)
                  : (context.tr('rd_tag_transfer'), AppColors.primary),
              if (it.isOnOrder) (context.tr('rd_tag_on_order'), AppColors.warning),
            ],
            onTap: () => openProductDetail(context, it.itemCode,
                name: it.name, myWarehouses: [widget.warehouseCode]),
          ),
      ],
      onViewAll: d.bleedingItems.isEmpty ? null : () => _openItems(BranchItemsType.bleeding, d.name),
    );
  }

  Widget _trappedCard(BuildContext context, BranchDetail d) {
    return _productSection(
      context: context,
      icon: Icons.lock_clock_rounded,
      accent: AppColors.warning,
      titleKey: 'bd_trapped_title',
      total: d.trappedTotal > 0 ? sarCompact(d.trappedTotal) : null,
      tiles: [
        for (final it in d.trappedItems.take(3))
          ProductMetricTile(
            imageUrl: it.imageUrl,
            name: it.name,
            value: sarCompact(it.primaryValue),
            valueLabel: context.tr('rd_capital_short'),
            accent: AppColors.warning,
            stock: it.currentStock,
            healthStatus: it.healthStatus,
            onTap: () => openProductDetail(context, it.itemCode,
                name: it.name, myWarehouses: [widget.warehouseCode]),
          ),
      ],
      onViewAll: d.trappedItems.isEmpty ? null : () => _openItems(BranchItemsType.trapped, d.name),
    );
  }

  void _openItems(BranchItemsType type, String branchName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BranchItemsPage(
          warehouseCode: widget.warehouseCode,
          branchName: branchName,
          type: type,
          period: _period,
        ),
      ),
    );
  }

  /// Shared card for the three product sections: an icon-chip header (with an
  /// optional total), item rows separated by hairlines, and a "view all" link.
  Widget _productSection({
    required BuildContext context,
    required IconData icon,
    required Color accent,
    required String titleKey,
    required List<Widget> tiles,
    String? total,
    VoidCallback? onViewAll,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: AppRadius.borderMd),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.tr(titleKey),
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (total != null)
                Text(total, style: AppTypography.titleSmall.copyWith(color: accent, fontWeight: FontWeight.w900)),
            ],
          ),
          if (tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('—', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
            )
          else ...[
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.borderLight),
              tiles[i],
            ],
          ],
          if (onViewAll != null) ...[
            Divider(height: AppSpacing.md, color: AppColors.borderLight),
            _viewAllButton(context, accent, onViewAll),
          ],
        ],
      ),
    );
  }

  Widget _viewAllButton(BuildContext context, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.tr('rd_view_all'),
                style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            Icon(AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _opsCard(BuildContext context, BranchDetail d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.tr('bd_ops')),
          _opRow(context, Icons.verified_outlined, context.tr('ops_quality'), d.ops.qualityPending, AppDomain.quality.accent),
          _opRow(context, Icons.inventory_2_outlined, context.tr('ops_counting'), d.ops.countingActive, AppDomain.counting.accent),
          _opRow(context, Icons.swap_horiz_rounded, context.tr('ops_transfers'), d.ops.transfersNew, AppDomain.transfers.accent),
          _opRow(context, Icons.bolt_rounded, context.tr('ops_zooboxi'), d.ops.zooboxiPending, AppDomain.zooboxi.accent),
        ],
      ),
    );
  }

  Widget _opRow(BuildContext context, IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.bodySmall)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: count > 0 ? color.withValues(alpha: 0.12) : AppColors.borderLight,
              borderRadius: AppRadius.borderFull,
            ),
            child: Text('$count',
                style: AppTypography.labelMedium
                    .copyWith(color: count > 0 ? color : AppColors.textTertiary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
