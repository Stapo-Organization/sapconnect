import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/delivery_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';

/// Per-warehouse availability, collapsed by default.
///
/// Most customers only need the promise above; the ones who care *where* the
/// stock is — because they'd rather collect it, or they're buying for a
/// clinic — get the full picture one tap away instead of not at all.
class WarehousePanel extends StatelessWidget {
  const WarehousePanel({super.key, required this.rows});

  final List<WarehouseAvailability> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final cs = context.cs;
    final withStock = rows.where((r) => r.stock > 0).toList();
    if (withStock.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // The default expansion tile paints its own dividers, which fight the
        // card's border.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Icon(Icons.warehouse_rounded, size: 18, color: cs.onSurfaceVariant),
          title: Text(l.pdpAvailability, style: context.tt.titleSmall),
          subtitle: Text(
            l.pdpStockUnits(withStock.fold<int>(0, (sum, r) => sum + r.stock)),
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          children: [
            for (final row in withStock)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(tierIcon(row.tier), size: 15, color: context.zb.tier(row.tier).fg),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        row.warehouseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodyMedium,
                      ),
                    ),
                    Text(
                      l.pdpStockUnits(row.stock),
                      style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
