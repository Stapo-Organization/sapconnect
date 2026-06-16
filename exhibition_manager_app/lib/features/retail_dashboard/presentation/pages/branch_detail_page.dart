import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/retail_models.dart';
import '../../data/retail_dashboard_repository.dart';
import '../widgets/sales_profit_chart.dart';

/// Full drill-down for one exhibition: revenue + trend, top sellers, pulse
/// vitals, money levers and operations — all filterable by period.
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
  bool _loading = true;
  bool _hasError = false;
  String _period = 'month';

  static const _periods = ['today', 'week', 'month'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final r = await _repo.getBranch(widget.warehouseCode, period: _period);
    if (!mounted) return;
    setState(() {
      _data = r.data;
      _loading = false;
      _hasError = !r.success;
    });
  }

  void _setPeriod(String p) {
    _period = p;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final accent = AppDomain.admin.accent;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: _data?.name ?? widget.initialName),
        body: RefreshIndicator(
          onRefresh: _load,
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
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _load))];
    }
    final d = _data!;
    return [
      _revenueCard(context, d),
      const SizedBox(height: AppSpacing.base),
      if (d.trend.points.isNotEmpty) ...[
        SalesProfitChart(trend: d.trend, salesColor: accent),
        const SizedBox(height: AppSpacing.base),
      ],
      if (d.score != null) ...[_vitalsCard(context, d, accent), const SizedBox(height: AppSpacing.base)],
      _leversCard(context, d),
      const SizedBox(height: AppSpacing.base),
      if (d.topProducts.isNotEmpty) ...[_topProductsCard(context, d), const SizedBox(height: AppSpacing.base)],
      _opsCard(context, d),
    ];
  }

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
            child: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 19),
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

  Widget _leversCard(BuildContext context, BranchDetail d) {
    return Column(
      children: [
        _leverBlock(
          context,
          title: context.tr('bd_bleeding_title'),
          total: d.bleedingTotal,
          items: d.bleedingItems,
          color: AppColors.error,
          icon: Icons.trending_down_rounded,
        ),
        const SizedBox(height: AppSpacing.base),
        _leverBlock(
          context,
          title: context.tr('bd_trapped_title'),
          total: d.trappedTotal,
          items: d.trappedItems,
          color: AppColors.warning,
          icon: Icons.lock_clock_rounded,
        ),
      ],
    );
  }

  Widget _leverBlock(
    BuildContext context, {
    required String title,
    required double total,
    required List<LeverItem> items,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.titleSmall)),
              Text(sarCompact(total), style: AppTypography.titleSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('—', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
            )
          else
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(it.name, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(sarCompact(it.primaryValue),
                          style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _topProductsCard(BuildContext context, BranchDetail d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.tr('bd_top_products')),
          ...d.topProducts.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text('${i + 1}', style: AppTypography.labelMedium.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(p.name, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${unitsLabel(p.units)} ${context.tr('bd_units')}',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
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
