import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/delivery_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';

/// The delivery promise card — the single most decisive block on the page.
///
/// It lists every tier that can actually serve this customer with dated
/// promises, because "2 hours from Al-Nakheel, or Thursday from the hub" is a
/// genuinely different purchase decision from a flat "in stock".
class DeliveryCard extends StatelessWidget {
  const DeliveryCard({super.key, required this.delivery});

  final DeliveryInfo delivery;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final tiers = delivery.tiers.where((t) => t.stock > 0).toList();
    final headline = delivery.headline;

    if (tiers.isEmpty && (headline == null || headline.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: 18, color: cs.primary),
              Gap.w8,
              Text(l.pdpDelivery, style: context.tt.titleSmall),
              const Spacer(),
              if (delivery.reachableTotal > 0)
                Text(
                  l.pdpReachable(delivery.reachableTotal),
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          if (headline != null && headline.isNotEmpty) ...[
            Gap.h8,
            Text(
              headline,
              style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (tiers.isNotEmpty) ...[
            Gap.h12,
            for (final (index, tier) in tiers.indexed) ...[
              if (index > 0) Divider(height: 20, color: cs.outlineVariant),
              _TierRow(tier: tier),
            ],
          ],
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier});

  final DeliveryTier tier;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final pair = context.zb.tier(tier.tier);
    final when = tier.relativeLabel ?? tier.dateLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: pair.bg, shape: BoxShape.circle),
          child: Icon(tierIcon(tier.tier), size: 17, color: pair.fg),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      tier.label ?? _fallbackLabel(l, tier.tier),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(color: pair.fg),
                    ),
                  ),
                  if (when != null && when.isNotEmpty) ...[
                    Gap.w8,
                    Flexible(
                      child: Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Gap.h4,
              Text(
                [
                  if (tier.warehouseName != null) tier.warehouseName!,
                  l.pdpStockUnits(tier.stock),
                  if (tier.dateLabel != null && tier.relativeLabel != null) tier.dateLabel!,
                ].join(' · '),
                maxLines: 2,
                style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The server normally sends a localized label; this only covers a payload
  /// that omitted it.
  static String _fallbackLabel(L l, String tier) => switch (tier) {
        'express' => l.tierExpress,
        'same_day' || 'sameday' || 'city' => l.tierSameDay,
        'pickup' => l.tierPickup,
        _ => l.tierShipping,
      };
}
