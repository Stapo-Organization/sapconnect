import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
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

/// The three "view all" section types behind the branch-detail cards.
enum BranchItemsType { bleeding, trapped, top }

/// Full list for one branch section (bleeding / trapped / best-sellers) with a
/// summary strip and every item rendered as a [ProductMetricTile].
class BranchItemsPage extends StatefulWidget {
  final String warehouseCode;
  final String branchName;
  final BranchItemsType type;
  final String? period; // only best-sellers is period-scoped
  final String? from;
  final String? to;

  const BranchItemsPage({
    super.key,
    required this.warehouseCode,
    required this.branchName,
    required this.type,
    this.period,
    this.from,
    this.to,
  });

  @override
  State<BranchItemsPage> createState() => _BranchItemsPageState();
}

class _BranchItemsPageState extends State<BranchItemsPage> {
  final RetailDashboardRepository _repo = RetailDashboardRepository();
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  bool _hasError = false;
  int _bleedingTab = 0; // bleeding only: 0=all, 1=OOS (reorder), 2=transfer

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _typeParam => switch (widget.type) {
        BranchItemsType.trapped => 'trapped',
        BranchItemsType.top => 'top',
        BranchItemsType.bleeding => 'bleeding',
      };

  Color get _accent => switch (widget.type) {
        BranchItemsType.bleeding => AppColors.error,
        BranchItemsType.trapped => AppColors.warning,
        BranchItemsType.top => AppColors.primary,
      };

  String get _titleKey => switch (widget.type) {
        BranchItemsType.bleeding => 'bd_bleeding_title',
        BranchItemsType.trapped => 'bd_trapped_title',
        BranchItemsType.top => 'bd_top_products',
      };

  String get _subKey => switch (widget.type) {
        BranchItemsType.bleeding => 'bd_bleeding_sub',
        BranchItemsType.trapped => 'bd_trapped_sub',
        BranchItemsType.top => 'bd_top_sub',
      };

  IconData get _icon => switch (widget.type) {
        BranchItemsType.bleeding => Icons.trending_down_rounded,
        BranchItemsType.trapped => Icons.lock_clock_rounded,
        BranchItemsType.top => Icons.local_fire_department_rounded,
      };

  Future<void> _load() async {
    setState(() {
      _loading = _items == null;
      _hasError = false;
    });
    final r = await _repo.getBranchItems(
      widget.warehouseCode,
      type: _typeParam,
      period: widget.type == BranchItemsType.top ? widget.period : null,
      from: widget.from,
      to: widget.to,
    );
    if (!mounted) return;
    setState(() {
      _items = r.success ? r.items : _items;
      _hasError = !r.success && _items == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr(_titleKey)),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxl),
            children: _content(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    if (_loading) {
      return [
        const SkeletonCard(height: 92),
        const SizedBox(height: AppSpacing.base),
        for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SkeletonCard(height: 66)),
      ];
    }
    if (_hasError) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _load))];
    }
    final all = _items ?? const [];
    if (all.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.huge),
          child: EmptyState(icon: Icons.inventory_2_outlined, title: context.tr('rd_no_items')),
        ),
      ];
    }
    final isBleeding = widget.type == BranchItemsType.bleeding;
    final visible = _visibleItems(all);
    return [
      _summaryStrip(context, all),
      const SizedBox(height: AppSpacing.base),
      if (isBleeding) ...[
        _bleedingTabs(context, all),
        const SizedBox(height: AppSpacing.md),
      ],
      if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: EmptyState(icon: Icons.check_circle_outline, title: context.tr('rd_no_items_tab')),
        )
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.borderLight),
                _tile(context, visible[i], i),
              ],
            ],
          ),
        ).animate(key: ValueKey(_bleedingTab)).fadeIn(duration: 220.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    ];
  }

  /// Bleeding items filtered by the selected remedy tab (all types else pass through).
  List<Map<String, dynamic>> _visibleItems(List<Map<String, dynamic>> all) {
    if (widget.type != BranchItemsType.bleeding || _bleedingTab == 0) return all;
    final wantReorder = _bleedingTab == 1;
    return all.where((m) => ('${m['remedy'] ?? 'transfer'}' == 'reorder') == wantReorder).toList();
  }

  Widget _bleedingTabs(BuildContext context, List<Map<String, dynamic>> all) {
    final oos = all.where((m) => '${m['remedy'] ?? 'transfer'}' == 'reorder').length;
    return AppSegmentedControl(
      activeColor: _accent,
      selectedIndex: _bleedingTab,
      onChanged: (i) => setState(() => _bleedingTab = i),
      items: [
        SegmentItem(context.tr('rd_tab_all'), badge: all.length),
        SegmentItem(context.tr('rd_tab_oos'), badge: oos),
        SegmentItem(context.tr('rd_tab_transfer'), badge: all.length - oos),
      ],
    );
  }

  /// Status chips for a bleeding tile: the remedy (only in the "All" tab, so the
  /// two groups are distinguishable) plus a "قيد الطلب" flag when a PO already exists.
  List<(String, Color)> _bleedingChips(BuildContext context, LeverItem it) {
    final chips = <(String, Color)>[];
    if (_bleedingTab == 0) {
      chips.add(it.isOos
          ? (context.tr('rd_tag_reorder'), AppColors.error)
          : (context.tr('rd_tag_transfer'), AppColors.primary));
    }
    if (it.isOnOrder) chips.add((context.tr('rd_tag_on_order'), AppColors.warning));
    return chips;
  }

  Widget _summaryStrip(BuildContext context, List<Map<String, dynamic>> items) {
    final (total, totalLabel) = _total(items);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: _accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(_icon, color: _accent, size: 21),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.branchName,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(context.tr(_subKey),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total, style: AppTypography.titleMedium.copyWith(color: _accent, fontWeight: FontWeight.w900)),
              Text('${items.length} · $totalLabel',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  (String, String) _total(List<Map<String, dynamic>> items) {
    switch (widget.type) {
      case BranchItemsType.bleeding:
        final t = items.fold<double>(0, (a, m) => a + (double.tryParse('${m['lost_revenue_monthly'] ?? 0}') ?? 0));
        return (sarCompact(t), AppLocalizations.isArabic ? 'صنف' : 'items');
      case BranchItemsType.trapped:
        final t = items.fold<double>(0, (a, m) => a + (double.tryParse('${m['capital_at_risk_sar'] ?? 0}') ?? 0));
        return (sarCompact(t), AppLocalizations.isArabic ? 'صنف' : 'items');
      case BranchItemsType.top:
        final t = items.fold<double>(0, (a, m) => a + (double.tryParse('${m['units'] ?? 0}') ?? 0));
        return (unitsLabel(t), AppLocalizations.isArabic ? 'صنف' : 'items');
    }
  }

  Widget _tile(BuildContext context, Map<String, dynamic> m, int index) {
    switch (widget.type) {
      case BranchItemsType.bleeding:
        final it = LeverItem.bleeding(m);
        return ProductMetricTile(
          imageUrl: it.imageUrl,
          name: it.name,
          value: sarCompact(it.primaryValue),
          valueLabel: context.tr('rd_lost_monthly'),
          accent: AppColors.error,
          stock: it.currentStock,
          healthStatus: it.healthStatus,
          chips: _bleedingChips(context, it),
          onTap: () => openProductDetail(context, it.itemCode,
              name: it.name, myWarehouses: [widget.warehouseCode]),
        );
      case BranchItemsType.trapped:
        final it = LeverItem.trapped(m);
        return ProductMetricTile(
          imageUrl: it.imageUrl,
          name: it.name,
          value: sarCompact(it.primaryValue),
          valueLabel: context.tr('rd_capital_short'),
          accent: AppColors.warning,
          stock: it.currentStock,
          healthStatus: it.healthStatus,
          onTap: () => openProductDetail(context, it.itemCode,
              name: it.name, myWarehouses: [widget.warehouseCode]),
        );
      case BranchItemsType.top:
        final it = TopProduct.fromJson(m);
        return ProductMetricTile(
          imageUrl: it.imageUrl,
          name: it.name,
          value: unitsLabel(it.units),
          valueLabel: context.tr('bd_units'),
          accent: AppColors.primary,
          rank: index + 1,
          onTap: () => openProductDetail(context, it.itemCode,
              name: it.name, myWarehouses: [widget.warehouseCode]),
        );
    }
  }
}
