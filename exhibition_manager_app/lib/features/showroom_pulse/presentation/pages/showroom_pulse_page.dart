import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_button.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/gradient_header.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/progress_ring.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/pulse_overview.dart';
import '../controllers/showroom_pulse_controller.dart';
import '../widgets/lever_item_card.dart';
import '../widgets/pulse_helpers.dart';
import 'lever_list_page.dart';
import 'basket_list_page.dart';
import 'package:exhibition_manager_app/features/product_search/presentation/product_detail_launcher.dart';

/// نبض المعرض (Showroom Pulse) — the per-branch decision dashboard:
/// a health score + four vital signs, then the three money levers
/// (🔴 stop the bleeding · 🟡 free your cash · 🟢 grow the basket).
class ShowroomPulsePage extends StatefulWidget {
  const ShowroomPulsePage({super.key});

  @override
  State<ShowroomPulsePage> createState() => _ShowroomPulsePageState();
}

class _ShowroomPulsePageState extends State<ShowroomPulsePage> {
  final ShowroomPulseController _controller = ShowroomPulseController();

  final Set<String> _transferRequested = {};
  final Set<String> _discountSuggested = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestTransfer(BleedingItem item) async {
    if (_busy.contains(item.itemCode)) return;
    setState(() => _busy.add(item.itemCode));
    final res = await _controller.requestTransfer(item.itemCode);
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
    final res = await _controller.suggestDiscount(item.itemCode);
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

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTypography.bodyMedium.copyWith(color: Colors.white)),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _openLever({required String type, required String title, required Color color}) {
    final data = _controller.data;
    if (data == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LeverListPage(
        type: type,
        warehouse: data.warehouse.code,
        warehouseName: data.warehouse.name,
        title: title,
        color: color,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_controller.hasError) {
              return _errorState();
            }
            final data = _controller.data;
            if (data == null) return _errorState();
            return RefreshIndicator(
              color: AppDomain.showroomPulse.accent,
              onRefresh: _controller.refresh,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _header(data),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.score != null) _vitalsCard(data.vitals),
                        const SizedBox(height: AppSpacing.lg),
                        _bleedingSection(data.bleeding),
                        const SizedBox(height: AppSpacing.lg),
                        _trappedSection(data.trapped),
                        const SizedBox(height: AppSpacing.lg),
                        _basketSection(data.basket),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Header (score) ──────────────────────────────────────────

  Widget _header(PulseOverview data) {
    final score = data.score;
    return GradientHeader(
      title: context.tr('showroom_pulse_title'),
      subtitle: data.warehouse.name,
      gradient: AppDomain.showroomPulse.gradient,
      actions: [
        IconButton(
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: context.tr('update'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.availableWarehouses.length > 1) ...[
            _branchSwitcher(data),
            const SizedBox(height: AppSpacing.md),
          ],
          score == null ? _scorePlaceholder() : _scoreRow(score),
        ],
      ),
    );
  }

  Widget _scoreRow(PulseScore score) {
    return Row(
      children: [
        ProgressRing(
          percent: score.value,
          size: 104,
          stroke: 10,
          color: Colors.white,
          trackColor: Colors.white.withValues(alpha: 0.22),
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.value.round().toString(),
                style: AppTypography.headlineMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              Text(
                scoreLabel(score.value),
                style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (score.rank != null && score.totalBranches != null)
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      context
                          .tr('sp_rank_of_branches')
                          .replaceAll('{rank}', '${score.rank}')
                          .replaceAll('{total}', '${score.totalBranches}'),
                      style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              if (score.trend != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _trendChip(score.trend!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _trendChip(double trend) {
    final up = trend >= 0;
    final color = up ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: AppRadius.borderFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            context
                .tr('sp_trend_this_week')
                .replaceAll('{n}', '${up ? '+' : ''}${trend.toStringAsFixed(0)}'),
            style: AppTypography.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _scorePlaceholder() {
    return Text(
      context.tr('sp_score_placeholder'),
      style: AppTypography.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.9)),
    );
  }

  Widget _branchSwitcher(PulseOverview data) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: data.availableWarehouses.map((w) {
        final selected = w.code == data.warehouse.code;
        return ChoiceChip(
          label: Text(w.name),
          selected: selected,
          onSelected: (_) {
            if (!selected) _controller.switchWarehouse(w.code);
          },
          labelStyle: AppTypography.labelMedium.copyWith(
            color: selected ? AppDomain.showroomPulse.accentDark : Colors.white,
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          selectedColor: Colors.white,
        );
      }).toList(),
    );
  }

  // ─── Vitals ──────────────────────────────────────────────────

  Widget _vitalsCard(List<PulseVital> vitals) {
    if (vitals.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < vitals.length; i++) ...[
            _vitalBar(vitals[i]),
            if (i != vitals.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _vitalBar(PulseVital v) {
    final hasValue = v.value != null;
    final pct = (v.value ?? 0).clamp(0, 100).toDouble();
    final color = vitalColor(pct, hasValue);
    final valueText = !hasValue
        ? '—'
        : (v.key == 'basket_size' && v.raw != null
            ? context.tr('sp_items_per_invoice').replaceAll('{n}', v.raw!.toStringAsFixed(1))
            : pctLabel(pct));

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(vitalLabel(v.key), style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EDF4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 92,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: AppTypography.labelMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ─── 🔴 Bleeding lever ───────────────────────────────────────

  Widget _bleedingSection(BleedingLever lever) {
    return _leverScaffold(
      color: kBleedingColor,
      title: context.tr('bd_bleeding_title'),
      total: lever.totalMonthlySar > 0
          ? context.tr('sp_at_risk_per_month').replaceAll('{amount}', sar(lever.totalMonthlySar))
          : null,
      emptyText: context.tr('sp_no_bleeding_now'),
      isEmpty: lever.items.isEmpty,
      children: lever.items
          .map((item) => bleedingCard(
                item,
                busy: _busy.contains(item.itemCode),
                requested: _transferRequested.contains(item.itemCode),
                onRequest: () => _requestTransfer(item),
                onOpenProduct: () => _openProduct(item.itemCode, item.name),
              ))
          .toList(),
      showAllCount: lever.totalCount > lever.items.length ? lever.totalCount : null,
      onShowAll: () => _openLever(type: 'bleeding', title: context.tr('bd_bleeding_title'), color: kBleedingColor),
    );
  }

  // ─── 🟡 Trapped lever ────────────────────────────────────────

  Widget _trappedSection(TrappedLever lever) {
    return _leverScaffold(
      color: kTrappedColor,
      title: context.tr('sp_lever_trapped_title'),
      total: lever.totalSar > 0
          ? context.tr('sp_idle_capital_total').replaceAll('{amount}', sar(lever.totalSar))
          : null,
      emptyText: context.tr('sp_no_trapped_now'),
      isEmpty: lever.items.isEmpty,
      children: lever.items
          .map((item) => trappedCard(
                item,
                busy: _busy.contains(item.itemCode),
                suggested: _discountSuggested.contains(item.itemCode),
                onSuggest: () => _suggestDiscount(item),
                onOpenProduct: () => _openProduct(item.itemCode, item.name),
              ))
          .toList(),
      showAllCount: lever.totalCount > lever.items.length ? lever.totalCount : null,
      onShowAll: () => _openLever(type: 'trapped', title: context.tr('sp_lever_trapped_title'), color: kTrappedColor),
    );
  }

  // ─── 🟢 Basket lever ─────────────────────────────────────────

  Widget _basketSection(List<BasketPair> pairs) {
    final total = _controller.data?.basketTotalCount ?? pairs.length;
    return _leverScaffold(
      color: kBasketColor,
      title: context.tr('sp_lever_basket_title'),
      total: null,
      emptyText: context.tr('sp_no_basket_now'),
      isEmpty: pairs.isEmpty,
      children: pairs
          .map((p) => basketCard(p, onOpenItem: (ref) => _openProduct(ref.code, ref.name)))
          .toList(),
      showAllCount: total > pairs.length ? total : null,
      onShowAll: _openBasketAll,
    );
  }

  void _openProduct(String code, String name) {
    final wh = _controller.data?.warehouse.code;
    openProductDetail(context, code, name: name, myWarehouses: wh != null ? [wh] : const []);
  }

  void _openBasketAll() {
    final data = _controller.data;
    if (data == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BasketListPage(
        warehouse: data.warehouse.code,
        warehouseName: data.warehouse.name,
      ),
    ));
  }

  // ─── Section scaffold ────────────────────────────────────────

  Widget _leverScaffold({
    required Color color,
    required String title,
    required String? total,
    required String emptyText,
    required bool isEmpty,
    required List<Widget> children,
    int? showAllCount,
    VoidCallback? onShowAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            if (showAllCount != null && onShowAll != null)
              TextButton(
                onPressed: onShowAll,
                style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('sp_show_all_n').replaceAll('{n}', '$showAllCount'),
                        style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_left_rounded, size: 18, color: color),
                  ],
                ),
              ),
          ],
        ),
        if (total != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18),
            child: Text(total, style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (isEmpty)
          AppCard(child: Text(emptyText, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)))
        else
          ...children,
      ],
    );
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
            Text(context.tr('sp_load_error'), style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: context.tr('retry'),
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: _controller.refresh,
            ),
          ],
        ),
      ),
    );
  }
}
