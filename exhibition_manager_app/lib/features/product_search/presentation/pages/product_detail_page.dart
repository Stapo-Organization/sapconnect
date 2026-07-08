import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_button.dart';
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

  static const Color _accent = Color(0xFF4C5FD5);
  static const Color _accentDark = Color(0xFF3A4BB0);

  bool _loading = true;
  String? _error;
  ProductDetail? _data;
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
    final res = await _repo.detail(widget.itemCode, branches: widget.myWarehouses);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = res.data;
      _error = res.success ? null : (res.error ?? 'تعذّر تحميل المنتج');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'تفاصيل المنتج',
            style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : (_data == null)
                ? _errorState()
                : RefreshIndicator(
                    color: _accent,
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
  static const Color _transferAccent = Color(0xFF0E9F8E);

  Widget _transferSuggestionCard(ProductDetail d) {
    final s = d.transferSuggestions;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: _transferAccent.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: _transferAccent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _transferAccent.withValues(alpha: 0.16), borderRadius: AppRadius.borderMd),
                child: const Icon(Icons.swap_horiz_rounded, color: _transferAccent, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('مقترح التحويل الذكي',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('متوفر بمستودعات أخرى — انقله إلى ${s.first.targetName} بدل طلبه من المورد.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < s.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: _transferAccent.withValues(alpha: 0.15)),
            _suggestionRow(s[i]),
          ],
        ],
      ),
    );
  }

  Widget _suggestionRow(TransferSuggestion s) {
    final ctx = <String>[
      'متوفر بالمصدر ${fmtQty(s.sourceAvailable ?? 0)}',
      if (s.targetAds != null && s.targetAds! > 0) 'يبيع ${s.targetAds!.toStringAsFixed(1)}/يوم',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fromTo('من', s.sourceName, AppColors.textPrimary),
              const SizedBox(height: 3),
              _fromTo('إلى', s.targetName, _transferAccent),
              const SizedBox(height: 5),
              Text(ctx, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          children: [
            Text(fmtQty(s.quantity),
                style: AppTypography.titleMedium.copyWith(color: _transferAccent, fontWeight: FontWeight.w900)),
            Text('وحدة', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
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
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.borderFull),
          child: Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_accent, _accentDark],
        ),
        borderRadius: AppRadius.borderXl,
        boxShadow: [
          BoxShadow(color: _accentDark.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderLg),
                child: (d.imageUrl.isEmpty)
                    ? Icon(Icons.inventory_2_outlined, color: AppColors.textTertiary)
                    : Image.network(
                        d.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.inventory_2_outlined, color: AppColors.textTertiary),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _codeChips(d),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: AppSpacing.base),
          Text(
            fmtQty(d.totalStock),
            style: AppTypography.displayMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            'إجمالي المخزون في كل المستودعات',
            style: AppTypography.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: AppSpacing.md),
          // المحجوز / القادم / المتاح — turns "in stock" into "actually sellable":
          // المتاح = المخزون − المحجوز + القادم (straight from SAP).
          Row(
            children: [
              _heroStat('المحجوز', fmtQty(d.totalCommitted)),
              const SizedBox(width: AppSpacing.sm),
              _heroStat('القادم', fmtQty(d.totalOrdered)),
              const SizedBox(width: AppSpacing.sm),
              _heroStat('المتاح', fmtQty(d.totalAvailable), emphasize: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _glassPill(Icons.store_mall_directory_rounded, 'متوفر في ${d.warehouseCount} معرض'),
              if (d.retailPrice != null && d.retailPrice! > 0)
                _glassPill(Icons.sell_outlined, 'سعر البيع ${_price(d.retailPrice!)}'),
              if (d.uom != null && d.uom!.isNotEmpty) _glassPill(Icons.straighten_rounded, 'الوحدة ${d.uom}'),
              if (d.brand != null && d.brand!.isNotEmpty) _glassPill(Icons.label_outline_rounded, d.brand!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _codeChips(ProductDetail d) {
    final parts = <Widget>[
      Icon(Icons.tag_rounded, size: 13, color: Colors.white.withValues(alpha: 0.8)),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          d.itemCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    ];
    if (d.barcode != null && d.barcode!.isNotEmpty) {
      parts.addAll([
        const SizedBox(width: 12),
        Icon(Icons.qr_code_2_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            d.barcode!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ]);
    }
    return Row(children: parts);
  }

  Widget _heroStat(String label, String value, {bool emphasize = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: emphasize ? 0.26 : 0.13),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _glassPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: AppTypography.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
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
            Icon(Icons.warehouse_rounded, size: 18, color: _accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'الكميات في المستودعات والمعارض',
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
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
            WarehouseStockTile(row: filtered[i], isMine: mine.contains(filtered[i].warehouseCode)),
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
        return 'هذا المنتج غير متوفر في معارضك.';
      case _StockFilter.withStock:
        return 'لا يوجد مخزون متاح حالياً في أي مستودع.';
      case _StockFilter.all:
        return 'لا يوجد سجل مخزون لهذا المنتج.';
    }
  }

  Widget _filterBar(ProductDetail d, Set<String> mine) {
    final withStock = d.warehouses.where((w) => w.inStock > 0 || w.ordered > 0).length;
    final mineCount = mine.isEmpty ? 0 : d.warehouses.where((w) => mine.contains(w.warehouseCode)).length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _chip('فيها مخزون ($withStock)', _StockFilter.withStock),
        if (mine.isNotEmpty) _chip('معارضي ($mineCount)', _StockFilter.mine),
        _chip('الكل (${d.warehouses.length})', _StockFilter.all),
      ],
    );
  }

  Widget _chip(String label, _StockFilter f) {
    final sel = _filter == f;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => setState(() => _filter = f),
      showCheckmark: false,
      labelStyle: AppTypography.labelMedium.copyWith(
        color: sel ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: _accent,
      side: BorderSide(color: sel ? _accent : AppColors.border),
      visualDensity: VisualDensity.compact,
    );
  }

  String _price(double v) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '$s \u{E900}';
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? 'تعذّر تحميل المنتج',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _load),
          ],
        ),
      ),
    );
  }
}
