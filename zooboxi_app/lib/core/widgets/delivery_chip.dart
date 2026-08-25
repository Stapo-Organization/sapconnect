import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/catalog/data/product_models.dart' as models;

/// Maps a server tier key to the icon that carries its meaning at a glance.
IconData tierIcon(String tier) => switch (tier) {
      'express' => Icons.bolt_rounded,
      'same_day' || 'sameday' || 'city' => Icons.local_shipping_rounded,
      'pickup' => Icons.storefront_rounded,
      _ => Icons.inventory_2_rounded,
    };

/// The delivery promise chip — "خلال ساعتين", "غدًا", "3–5 أيام".
///
/// This is the store's most valuable single signal: it is the difference
/// between a product being *available* and being *available to you*, and it is
/// resolved per location. It gets a real color per tier so the eye can sort a
/// grid by speed without reading a word.
class DeliveryChipView extends StatelessWidget {
  const DeliveryChipView({super.key, required this.chip, this.compact = false});

  final models.DeliveryChip chip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pair = context.zb.tier(chip.tier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: pair.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tierIcon(chip.tier), size: compact ? 11 : 13, color: pair.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? context.tt.labelSmall : context.tt.labelMedium)?.copyWith(
                color: pair.fg,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
