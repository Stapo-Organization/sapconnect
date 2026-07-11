import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_button.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import '../../data/models/pulse_overview.dart';
import '../../data/showroom_pulse_repository.dart';
import '../widgets/lever_item_card.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';

/// Full list behind a money lever's "إظهار الكل" — its own page so the manager
/// can work through the whole list. Reuses the shared lever cards + actions.
class LeverListPage extends StatefulWidget {
  final String type; // 'bleeding' | 'trapped'
  final String warehouse;
  final String warehouseName;
  final String title;
  final Color color;

  const LeverListPage({
    super.key,
    required this.type,
    required this.warehouse,
    required this.warehouseName,
    required this.title,
    required this.color,
  });

  @override
  State<LeverListPage> createState() => _LeverListPageState();
}

class _LeverListPageState extends State<LeverListPage> {
  final ShowroomPulseRepository _repo = ShowroomPulseRepository();

  bool _loading = true;
  bool _error = false;
  List<BleedingItem> _bleeding = [];
  List<TrappedItem> _trapped = [];

  final Set<String> _busy = {};
  final Set<String> _transferRequested = {};
  final Set<String> _discountSuggested = {};

  bool get _isBleeding => widget.type == 'bleeding';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    if (_isBleeding) {
      final r = await _repo.getBleedingAll(warehouse: widget.warehouse);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = !r.success;
        _bleeding = r.items;
      });
    } else {
      final r = await _repo.getTrappedAll(warehouse: widget.warehouse);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = !r.success;
        _trapped = r.items;
      });
    }
  }

  Future<void> _requestTransfer(BleedingItem item) async {
    if (_busy.contains(item.itemCode)) return;
    setState(() => _busy.add(item.itemCode));
    final res = await _repo.requestTransfer(itemCode: item.itemCode, warehouseCode: widget.warehouse);
    if (!mounted) return;
    setState(() {
      _busy.remove(item.itemCode);
      if (res.success) _transferRequested.add(item.itemCode);
    });
    _toast(
        res.success
            ? (res.message ?? context.tr('sp_transfer_submitted'))
            : (res.error ?? context.tr('sp_transfer_failed')),
        ok: res.success);
  }

  Future<void> _suggestDiscount(TrappedItem item) async {
    if (_busy.contains(item.itemCode)) return;
    setState(() => _busy.add(item.itemCode));
    final res = await _repo.suggestDiscount(itemCode: item.itemCode, warehouseCode: widget.warehouse);
    if (!mounted) return;
    setState(() {
      _busy.remove(item.itemCode);
      if (res.success) _discountSuggested.add(item.itemCode);
    });
    _toast(
        res.success
            ? (res.message ?? context.tr('sp_discount_submitted'))
            : (res.error ?? context.tr('sp_discount_failed')),
        ok: res.success);
  }

  void _openProduct(String code, String name) {
    openProductDetail(context, code, name: name, myWarehouses: [widget.warehouse]);
  }

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final count = _isBleeding ? _bleeding.length : _trapped.length;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: widget.color,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.title,
            style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? _errorState()
                : count == 0
                    ? _emptyState()
                    : RefreshIndicator(
                        color: widget.color,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
                          itemCount: count + 1,
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Text(
                                  context
                                      .tr('sp_items_count_wh')
                                      .replaceAll('{n}', '$count')
                                      .replaceAll('{name}', widget.warehouseName),
                                  style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              );
                            }
                            final idx = i - 1;
                            if (_isBleeding) {
                              final item = _bleeding[idx];
                              return bleedingCard(
                                item,
                                busy: _busy.contains(item.itemCode),
                                requested: _transferRequested.contains(item.itemCode),
                                onRequest: () => _requestTransfer(item),
                                onOpenProduct: () => _openProduct(item.itemCode, item.name),
                              );
                            }
                            final item = _trapped[idx];
                            return trappedCard(
                              item,
                              busy: _busy.contains(item.itemCode),
                              suggested: _discountSuggested.contains(item.itemCode),
                              onSuggest: () => _suggestDiscount(item),
                              onOpenProduct: () => _openProduct(item.itemCode, item.name),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        _isBleeding ? context.tr('sp_no_bleeding_list') : context.tr('sp_no_trapped_list'),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('sp_list_load_error'), style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: context.tr('retry'), icon: Icons.refresh_rounded, expand: false, onPressed: _load),
        ],
      ),
    );
  }
}
