import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/bundles/data/bundles_repository.dart';
import 'package:exhibition_manager_app/features/bundles/data/models/bundle.dart';

/// Owner-only review feed of auto-suggested sellable bundles («حزم زوبوكسي»).
/// Approving one sends it to the store, which materialises it as a real
/// product within the hour; the backend re-guards every price server-side.
class BundlesPage extends StatefulWidget {
  const BundlesPage({super.key});

  @override
  State<BundlesPage> createState() => _BundlesPageState();
}

class _BundlesPageState extends State<BundlesPage> {
  final BundlesRepository _repo = BundlesRepository();
  static const _statuses = ['suggested', 'live', 'history'];

  List<Bundle> _bundles = [];
  bool _loading = true;
  bool _hasError = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getBundles(status: _statuses[_index]);
    if (mounted) {
      setState(() {
        _bundles = res.bundles;
        _loading = false;
        _hasError = !res.success;
      });
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _approve(Bundle b) async {
    final edited = await _showApproveSheet(b);
    if (edited == null) return;
    final r = await _repo.approve(b.id, price: edited.price);
    if (!mounted) return;
    if (r.success) {
      setState(() => _bundles.removeWhere((x) => x.id == b.id));
      _snack(context.tr('bundle_approved'), AppColors.success);
    } else {
      _snack(r.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _dismiss(Bundle b) async {
    final r = await _repo.reject(b.id);
    if (!mounted) return;
    if (r.success) {
      setState(() => _bundles.removeWhere((x) => x.id == b.id));
      _snack(context.tr('bundle_dismissed'), AppColors.textSecondary);
    } else {
      _snack(r.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _retire(Bundle b) async {
    final r = await _repo.retire(b.id);
    if (!mounted) return;
    if (r.success) {
      setState(() => _bundles.removeWhere((x) => x.id == b.id));
      _snack(context.tr('bundle_retired'), AppColors.textSecondary);
    } else {
      _snack(r.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  /// Approve sheet: shows the money math and allows an optional price edit.
  /// Returns null when cancelled.
  Future<({double? price})?> _showApproveSheet(Bundle b) {
    final controller = TextEditingController();
    return showModalBottomSheet<({double? price})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              b.nameAr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            _moneyRow(sheetCtx.tr('bundle_sum_label'), b.sumRetail, struck: true),
            _moneyRow(sheetCtx.tr('bundle_price_label'), b.bundlePrice, bold: true),
            _moneyRow(sheetCtx.tr('bundle_floor_label'), b.floorPrice, dim: true),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: sheetCtx.tr('bundle_edit_price'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final txt = controller.text.trim();
                Navigator.pop(sheetCtx, (price: txt.isEmpty ? null : double.tryParse(txt)));
              },
              child: Text(sheetCtx.tr('bundle_confirm_approve')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(String label, double value, {bool struck = false, bool bold = false, bool dim = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            sarAmount(value),
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: dim
                  ? AppColors.textTertiary
                  : (bold ? AppColors.textPrimary : AppColors.textSecondary),
              decoration: struck ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('bundles_title')),
      body: Column(
        children: [
          _tabs(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      itemCount: 4,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, _) => const SkeletonCard(height: 190),
                    )
                  : _hasError
                      ? ErrorStateWidget(onRetry: _load)
                      : _bundles.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 120),
                                Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textTertiary),
                                const SizedBox(height: AppSpacing.md),
                                Center(
                                  child: Text(
                                    context.tr('bundles_empty'),
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.base),
                              itemCount: _bundles.length,
                              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                              itemBuilder: (_, i) => _BundleCard(
                                bundle: _bundles[i],
                                statusTab: _statuses[_index],
                                onApprove: _approve,
                                onDismiss: _dismiss,
                                onRetire: _retire,
                              ).animate().fadeIn(delay: (40 * i).ms, duration: 250.ms).slideY(begin: .04),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(_statuses.length, (i) {
          final selected = i == _index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _index = i);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8)]
                      : null,
                ),
                child: Text(
                  context.tr('bundles_tab_${_statuses[i]}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* ═══════════════════════════════ card ═══════════════════════════════ */

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.statusTab,
    required this.onApprove,
    required this.onDismiss,
    required this.onRetire,
  });

  final Bundle bundle;
  final String statusTab;
  final Future<void> Function(Bundle) onApprove;
  final Future<void> Function(Bundle) onDismiss;
  final Future<void> Function(Bundle) onRetire;

  static const _speciesEmoji = {
    'cat': '🐱',
    'dog': '🐶',
    'bird': '🐦',
    'small_pet': '🐹',
    'mixed': '🐾',
  };

  Color _templateColor() {
    switch (bundle.template) {
      case 'stacking':
        return const Color(0xFF3B82F6);
      case 'variety':
        return const Color(0xFF8B5CF6);
      case 'companion':
        return const Color(0xFF10B981);
      case 'smart_gift':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tColor = _templateColor();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── chips row ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                context.tr('bundle_t_${bundle.template}'),
                fg: tColor,
                bg: tColor.withValues(alpha: .12),
              ),
              _chip(
                '${_speciesEmoji[bundle.species] ?? '🐾'} ${context.tr('bundle_sp_${bundle.species}')}',
                fg: AppColors.textSecondary,
                bg: AppColors.surfaceVariant,
              ),
              _chip(
                bundle.stockClass == 'express'
                    ? '⚡ ${context.tr('bundle_stock_express')}'
                    : '🏬 ${context.tr('bundle_stock_central')}',
                fg: bundle.stockClass == 'express' ? AppColors.warning : AppColors.info,
                bg: bundle.stockClass == 'express' ? AppColors.warningLight : AppColors.infoLight,
              ),
              if (bundle.freeLabel != null && bundle.freeLabel!.isNotEmpty)
                _chip(bundle.freeLabel!, fg: AppColors.error, bg: AppColors.errorLight),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            bundle.nameAr,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.5),
          ),
          if (bundle.subtitleAr != null && bundle.subtitleAr!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              bundle.subtitleAr!,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // ── components strip ──
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundle.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _componentTile(context, bundle.items[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── money row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                sarAmount(bundle.bundlePrice),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  sarAmount(bundle.sumRetail),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const Spacer(),
              _chip(
                '${context.tr('bundle_savings')} ${bundle.savingsPct.toStringAsFixed(0)}٪',
                fg: AppColors.success,
                bg: AppColors.successLight,
              ),
            ],
          ),

          // ── actions ──
          if (statusTab != 'history') ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: statusTab == 'suggested'
                  ? [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                          onPressed: () => onApprove(bundle),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(context.tr('bundle_approve')),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary),
                          onPressed: () => onDismiss(bundle),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(context.tr('bundle_dismiss')),
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () => onRetire(bundle),
                          icon: const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                          label: Text(context.tr('bundle_retire')),
                        ),
                      ),
                    ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _componentTile(BuildContext context, BundleItem item) {
    return SizedBox(
      width: 160,
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 48,
                    height: 48,
                    color: AppColors.surfaceVariant,
                    child: Icon(Icons.pets_rounded, size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ),
              if (item.isGift)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, height: 1.3, color: AppColors.textPrimary),
                ),
                Text(
                  '×${item.qty}${item.isGift ? ' · ${context.tr('bundle_gift_chip')}' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: item.isGift ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required Color fg, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
