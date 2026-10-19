import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/status_badge.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/product_models.dart';

/// The product screens share the app's single accent (no section hue).
Color get kProductAccent => AppColors.primary;

/// Integer quantity, grouped with the locale-aware thousands separator.
String fmtQty(num v) => intGrouped(v);

/// Product thumbnail on white with a hairline (Shopify media box) and a
/// graceful fallback icon.
Widget productThumb(String? url, {double size = 56, Color? accent}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size >= 56 ? 10 : 8),
      border: Border.all(color: AppColors.borderLight),
    ),
    clipBehavior: Clip.antiAlias,
    child: (url == null || url.isEmpty)
        ? Icon(Icons.image_outlined, size: size * 0.42, color: AppColors.textTertiary)
        : Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(Icons.image_outlined, size: size * 0.42, color: AppColors.textTertiary),
          ),
  );
}

/// A search result as a Shopify resource row — thumb, name (2 lines), code
/// and barcode in mono, and the network stock as a tabular number (or an
/// "out of stock" badge). Meant to sit inside an [AppSection].
class ProductHitTile extends StatefulWidget {
  final ProductHit hit;
  final VoidCallback onTap;

  const ProductHitTile({super.key, required this.hit, required this.onTap});

  @override
  State<ProductHitTile> createState() => _ProductHitTileState();
}

class _ProductHitTileState extends State<ProductHitTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    final inStock = hit.totalStock > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        color: _down ? AppColors.secondary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            productThumb(hit.imageUrl, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary, height: 1.35),
                  ),
                  const SizedBox(height: 3),
                  _codeLine(),
                ],
              ),
            ),
            const SizedBox(width: 10),
            inStock
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtQty(hit.totalStock), style: AppTypography.numeric.copyWith(color: AppColors.textPrimary)),
                      Text(context.tr('ps_network_stock'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 11)),
                    ],
                  )
                : StatusBadge(label: context.tr('ps_out_of_stock'), color: AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _codeLine() {
    final hit = widget.hit;
    final mono = AppTypography.monoSmall.copyWith(color: AppColors.textSecondary, fontSize: 11.5);
    return Row(
      children: [
        Flexible(child: Text(hit.itemCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono)),
        if (hit.barcode != null && hit.barcode!.isNotEmpty) ...[
          Text('  ·  ', style: mono.copyWith(color: AppColors.textTertiary)),
          Flexible(child: Text(hit.barcode!, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono)),
        ],
      ],
    );
  }
}

/// One warehouse / showroom stock line on the detail page.
class WarehouseStockTile extends StatelessWidget {
  final WarehouseStock row;
  final bool isMine; // one of the signed-in manager's branches
  /// SAP batches here, nearest expiry first (empty: not batch-managed / none).
  final List<ProductBatch> batches;

  const WarehouseStockTile({super.key, required this.row, this.isMine = false, this.batches = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isMine ? AppColors.textPrimary : AppColors.borderLight, width: isMine ? 1.4 : 1),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: warehouse identity ──
          Row(
            children: [
              GlowIconChip(icon: Icons.storefront_outlined, color: AppColors.primary, size: 32, iconSize: 18),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  row.warehouseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Text(row.warehouseCode, style: AppTypography.monoSmall.copyWith(color: AppColors.textTertiary, fontSize: 11)),
              if (isMine) ...[
                const SizedBox(width: 6),
                StatusBadge(label: context.tr('ps_your_showroom'), color: AppColors.info),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // ── Metrics strip: المخزون · المحجوز · القادم · المتاح ──
          Row(
            children: [
              _metric(context.tr('ps_stock'), row.inStock, AppColors.textPrimary),
              _vsep(),
              _metric(context.tr('ps_committed'), row.committed, row.committed > 0 ? AppColors.warning : AppColors.textTertiary),
              _vsep(),
              _metric(context.tr('ps_incoming'), row.ordered, row.ordered > 0 ? AppColors.info : AppColors.textTertiary),
              _vsep(),
              _metric(context.tr('ps_available'), row.available, _availColor(row.available), emphasize: true),
            ],
          ),
          if (batches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            BatchList(batches: batches),
          ],
        ],
      ),
    );
  }

  Widget _vsep() => Container(width: 1, height: 26, color: AppColors.borderLight);

  Widget _metric(String label, double value, Color color, {bool emphasize = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            fmtQty(value),
            style: AppTypography.numeric.copyWith(color: color, fontSize: emphasize ? 16 : 14),
          ),
          const SizedBox(height: 1),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  Color _availColor(double v) {
    if (v > 0) return AppColors.success;
    if (v < 0) return AppColors.error;
    return AppColors.textTertiary;
  }
}

/// A warehouse's batches: number, expiry date, time left (coloured by urgency)
/// and quantity. Three shown, the rest one tap away.
class BatchList extends StatefulWidget {
  final List<ProductBatch> batches;
  const BatchList({super.key, required this.batches});

  @override
  State<BatchList> createState() => _BatchListState();
}

class _BatchListState extends State<BatchList> {
  bool _all = false;

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  (String, Color) _left(BuildContext context, ProductBatch b) {
    final d = b.daysLeft;
    if (d == null) return (context.tr('ps_batch_no_date'), AppColors.textTertiary);
    if (d < 0) return (context.tr('ps_batch_expired'), AppColors.error);
    if (d <= 30) return (context.tr('ps_batch_days').replaceAll('{n}', '$d'), AppColors.error);
    if (d <= 90) return (context.tr('ps_batch_days').replaceAll('{n}', '$d'), AppColors.warning);
    return (context.tr('ps_batch_months').replaceAll('{n}', '${(d / 30).floor()}'), AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _all ? widget.batches : widget.batches.take(3).toList();
    final small = AppTypography.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.event_outlined, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(context.tr('ps_batches_title').replaceAll('{n}', '${widget.batches.length}'),
              style: small.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        for (final b in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Text(b.batch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppTypography.monoSmall.copyWith(color: AppColors.textPrimary, fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: Text(b.expiry != null ? _date(b.expiry!) : '—',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: small.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 3,
                child: Builder(builder: (context) {
                  final (label, color) = _left(context, b);
                  return Align(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                      child: Text(label, maxLines: 1, style: small.copyWith(color: color, fontWeight: FontWeight.w700)),
                    ),
                  );
                }),
              ),
              SizedBox(
                width: 44,
                child: Text(fmtQty(b.quantity),
                    textAlign: TextAlign.end, style: AppTypography.numeric.copyWith(fontSize: 13, color: AppColors.textPrimary)),
              ),
            ]),
          ),
        if (widget.batches.length > 3)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? context.tr('ps_batches_less') : context.tr('ps_batches_more').replaceAll('{n}', '${widget.batches.length}'),
                  style: small.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
