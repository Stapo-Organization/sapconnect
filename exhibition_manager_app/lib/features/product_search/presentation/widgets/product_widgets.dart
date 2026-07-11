import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/animated_icons.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/pressable.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/product_models.dart';

const Color kProductAccent = Color(0xFF4C5FD5); // cobalt-indigo (AppDomain.productSearch)

/// Integer quantity, grouped with the locale-aware thousands separator.
String fmtQty(num v) => intGrouped(v);

/// Rounded product thumbnail with a graceful fallback icon.
Widget productThumb(String? url, {double size = 56, Color? accent}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F9),
      borderRadius: AppRadius.borderMd,
      border: Border.all(color: (accent ?? AppColors.border).withValues(alpha: 0.18)),
    ),
    clipBehavior: Clip.antiAlias,
    child: (url == null || url.isEmpty)
        ? Icon(Icons.inventory_2_outlined, size: size * 0.46, color: AppColors.textTertiary)
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(Icons.inventory_2_outlined, size: size * 0.46, color: AppColors.textTertiary),
          ),
  );
}

/// A single search result row — thumb, name, code/barcode, and a network-stock
/// pill. The whole card taps through to the product detail page.
class ProductHitTile extends StatelessWidget {
  final ProductHit hit;
  final VoidCallback onTap;

  const ProductHitTile({super.key, required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inStock = hit.totalStock > 0;
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.borderXl,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderXl,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            productThumb(hit.imageUrl, size: 54, accent: kProductAccent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _codeLine(),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _stockPill(context, inStock),
          ],
        ),
      ),
    );
  }

  Widget _codeLine() {
    final parts = <Widget>[
      Icon(Icons.tag_rounded, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          hit.itemCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
        ),
      ),
    ];
    if (hit.barcode != null && hit.barcode!.isNotEmpty) {
      parts.addAll([
        const SizedBox(width: 10),
        Icon(Icons.qr_code_2_rounded, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            hit.barcode!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ]);
    }
    return Row(children: parts);
  }

  Widget _stockPill(BuildContext context, bool inStock) {
    final c = inStock ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: AppRadius.borderMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            inStock ? fmtQty(hit.totalStock) : context.tr('ps_out_of_stock'),
            style: AppTypography.titleSmall.copyWith(color: c, fontWeight: FontWeight.w800),
          ),
          Text(context.tr('ps_network_stock'), style: AppTypography.labelSmall.copyWith(color: c.withValues(alpha: 0.85), fontSize: 9)),
        ],
      ),
    );
  }
}

/// One warehouse / showroom stock line on the detail page.
class WarehouseStockTile extends StatelessWidget {
  final WarehouseStock row;
  final bool isMine; // one of the signed-in manager's branches

  const WarehouseStockTile({super.key, required this.row, this.isMine = false});

  @override
  Widget build(BuildContext context) {
    final has = row.inStock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMine ? kProductAccent.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: isMine ? kProductAccent.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: warehouse identity ──
          Row(
            children: [
              GlowIconChip(
                icon: Icons.store_mall_directory_rounded,
                color: has ? kProductAccent : AppColors.textTertiary,
                size: 32,
                iconSize: 17,
                borderRadius: AppRadius.borderMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  row.warehouseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Text(row.warehouseCode, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              if (isMine) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: kProductAccent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                  child: Text(context.tr('ps_your_showroom'), style: AppTypography.labelSmall.copyWith(color: kProductAccent, fontWeight: FontWeight.w700)),
                ),
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
        ],
      ),
    );
  }

  Widget _vsep() => Container(width: 1, height: 26, color: AppColors.border.withValues(alpha: 0.6));

  Widget _metric(String label, double value, Color color, {bool emphasize = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            fmtQty(value),
            style: (emphasize ? AppTypography.titleMedium : AppTypography.titleSmall)
                .copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 1),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
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
