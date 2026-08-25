import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/delivery_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/cart_models.dart';

/// One shipment group: its tier, its dated promise, its fee, and what's in it.
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({super.key, required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final pair = context.zb.tier(shipment.tier);
    final locale = Localizations.localeOf(context).languageCode;
    final when = shipment.relativeLabel ?? shipment.dateLabel;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: pair.fg.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: pair.bg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(tierIcon(shipment.tier), size: 16, color: pair.fg),
                Gap.w8,
                Expanded(
                  child: Text(
                    [
                      shipment.name ?? shipment.tier,
                      if (when != null && when.isNotEmpty) when,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelMedium?.copyWith(color: pair.fg),
                  ),
                ),
                Text(
                  shipment.free || shipment.fee <= 0
                      ? l.cartFree
                      : Fmt.price(shipment.fee, locale: locale),
                  style: context.tt.labelMedium?.copyWith(
                    color: pair.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in shipment.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodySmall,
                          ),
                        ),
                        Gap.w8,
                        Text(
                          l.cartLineQty(line.qty),
                          style: context.tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
