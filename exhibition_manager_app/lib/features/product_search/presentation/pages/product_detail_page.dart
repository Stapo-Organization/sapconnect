import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../../data/models/product_models.dart';
import '../../data/product_search_repository.dart';
import '../widgets/product_widgets.dart';

/// Product detail — identity (image, name, codes, brand, price) plus the live
/// stock across every warehouse & showroom, richest first.
/// How the warehouse list is filtered on the detail page.
enum _StockFilter { withStock, mine, all }

class ProductDetailPage extends StatefulWidget {
  final String itemCode;
  final String? fallbackName; // shown in the bar while the detail loads
  final List<String> myWarehouses; // signed-in manager's branches → "معارضي"

  const ProductDetailPage({
    super.key,
    required this.itemCode,
    this.fallbackName,
    this.myWarehouses = const [],
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ProductSearchRepository _repo = ProductSearchRepository();


  bool _loading = true;
  String? _error;
  ProductDetail? _data;
  BatchesByWarehouse _batches = const {};
  _StockFilter _filter = _StockFilter.withStock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Batches come live from SAP — fetched beside the detail, never blocking it.
    _repo.batches(widget.itemCode, branches: widget.myWarehouses).then((b) {
      if (mounted) setState(() => _batches = b);
    });
    final res = await _repo.detail(widget.itemCode, branches: widget.myWarehouses);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = res.data;
      _error = res.success ? null : (res.error ?? AppLocalizations.translate('ps_load_failed'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('ps_detail_title')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_data == null)
                ? _errorState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
                      children: [
                        _heroCard(_data!),
                        const SizedBox(height: AppSpacing.lg),
                        if (_data!.transferSuggestions.isNotEmpty) ...[
                          _transferSuggestionCard(_data!),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _stockSection(_data!),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ─── Smart transfer suggestion (shown for "transfer" bleeding items) ──
  static Color get _transferAccent => AppColors.textPrimary;

  Widget _transferSuggestionCard(ProductDetail d) {
    final s = d.transferSuggestions;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.45)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIconChip(icon: Icons.swap_horiz_rounded, color: AppColors.info, size: 34, iconSize: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.tr('ps_smart_transfer_title'),
                    style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(context.tr('ps_smart_transfer_sub').replaceAll('{name}', s.first.targetName),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < s.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: AppColors.borderLight),
            _suggestionRow(s[i]),
          ],
        ],
      ),
    );
  }

  Widget _suggestionRow(TransferSuggestion s) {
    final ctx = <String>[
      context.tr('ps_available_at_source').replaceAll('{n}', fmtQty(s.sourceAvailable ?? 0)),
      if (s.targetAds != null && s.targetAds! > 0)
        context.tr('ps_sells_per_day').replaceAll('{n}', s.targetAds!.toStringAsFixed(1)),
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fromTo(context.tr('from'), s.sourceName, AppColors.textPrimary),
              const SizedBox(height: 3),
              _fromTo(context.tr('to'), s.targetName, _transferAccent),
              const SizedBox(height: 5),
              Text(ctx, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          children: [
            Text(fmtQty(s.quantity), style: AppTypography.numeric.copyWith(color: AppColors.textPrimary, fontSize: 17)),
            Text(context.tr('bd_units'), style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _fromTo(String label, String name, Color nameColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: AppRadius.borderXs),
          child: Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 11)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: nameColor)),
        ),
      ],
    );
  }

  // ─── Hero (identity + headline stock) ───────────────────────

  Widget _heroCard(ProductDetail d) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productThumb(d.imageUrl, size: 84),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      _codeChips(d),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('ps_total_stock_all_warehouses'),
                    style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(fmtQty(d.totalStock), style: AppTypography.displayMedium.copyWith(color: AppColors.textPrimary, height: 1.1)),
                const SizedBox(height: AppSpacing.md),
                // المحجوز / القادم / المتاح — turns "in stock" into "actually sellable":
                // المتاح = المخزون − المحجوز + القادم (straight from SAP).
                Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _heroStat(context.tr('ps_committed'), fmtQty(d.totalCommitted)),
                        VerticalDivider(width: 1, color: AppColors.borderLight),
                        _heroStat(context.tr('ps_incoming'), fmtQty(d.totalOrdered)),
                        VerticalDivider(width: 1, color: AppColors.borderLight),
                        _heroStat(context.tr('ps_available'), fmtQty(d.totalAvailable), emphasize: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatChip(icon: Icons.storefront_outlined,
                        label: context.tr('ps_available_in_n_showrooms').replaceAll('{n}', '${d.warehouseCount}')),
                    if (d.retailPrice != null && d.retailPrice! > 0)
                      StatChip(icon: Icons.sell_outlined, label: context.tr('ps_retail_price').replaceAll('{n}', _price(d.retailPrice!))),
                    if (d.uom != null && d.uom!.isNotEmpty)
                      StatChip(icon: Icons.straighten_rounded, label: context.tr('ps_uom_label').replaceAll('{n}', d.uom!)),
                    if (d.brand != null && d.brand!.isNotEmpty) StatChip(icon: Icons.label_outline_rounded, label: d.brand!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeChips(ProductDetail d) {
    final mono = AppTypography.monoSmall.copyWith(color: AppColors.textSecondary);
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        Text(d.itemCode, style: mono),
        if (d.barcode != null && d.barcode!.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_2_rounded, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 3),
            Text(d.barcode!, style: mono),
          ]),
      ],
    );
  }

  Widget _heroStat(String label, String value, {bool emphasize = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric.copyWith(
                  color: emphasize ? AppColors.success : AppColors.textPrimary, fontSize: emphasize ? 17 : 15),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stock by warehouse ─────────────────────────────────────

  Widget _stockSection(ProductDetail d) {
    final mine = widget.myWarehouses.toSet();
    final filtered = d.warehouses.where((w) => _matches(w, mine)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('ps_stock_section_title'),
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Text(
              '${filtered.length}',
              style: AppTypography.titleSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _filterBar(d, mine),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              _emptyText(),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          for (var i = 0; i < filtered.length; i++) ...[
            WarehouseStockTile(
              row: filtered[i],
              isMine: mine.contains(filtered[i].warehouseCode),
              batches: _batches[filtered[i].warehouseCode] ?? const [],
            ),
            if (i != filtered.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  bool _matches(WarehouseStock w, Set<String> mine) {
    switch (_filter) {
      case _StockFilter.withStock:
        return w.inStock > 0 || w.ordered > 0;
      case _StockFilter.mine:
        return mine.contains(w.warehouseCode);
      case _StockFilter.all:
        return true;
    }
  }

  String _emptyText() {
    switch (_filter) {
      case _StockFilter.mine:
        return context.tr('ps_no_stock_in_my_showrooms');
      case _StockFilter.withStock:
        return context.tr('ps_no_stock_any_warehouse');
      case _StockFilter.all:
        return context.tr('ps_no_stock_record');
    }
  }

  Widget _filterBar(ProductDetail d, Set<String> mine) {
    final withStock = d.warehouses.where((w) => w.inStock > 0 || w.ordered > 0).length;
    final mineCount = mine.isEmpty ? 0 : d.warehouses.where((w) => mine.contains(w.warehouseCode)).length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _chip(context.tr('ps_filter_with_stock').replaceAll('{n}', '$withStock'), _StockFilter.withStock),
        if (mine.isNotEmpty) _chip(context.tr('ps_filter_mine').replaceAll('{n}', '$mineCount'), _StockFilter.mine),
        _chip('${context.tr('all')} (${d.warehouses.length})', _StockFilter.all),
      ],
    );
  }

  Widget _chip(String label, _StockFilter f) {
    return PillChip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f));
  }

  String _price(double v) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '$s \u{E900}';
  }

  Widget _errorState() {
    return ErrorStateWidget(title: _error ?? context.tr('ps_load_failed'), onRetry: _load);
  }
}
