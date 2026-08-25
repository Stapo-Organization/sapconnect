import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/catalog/data/product_models.dart';

/// The merchandising badge on a product card ("الأكثر طلبًا", "جديد").
///
/// The label is the server's — it computed *why* this product is notable. The
/// app only maps the type to a color pair, so the palette stays the app's and
/// a server change can't drop an off-brand colour into the grid.
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.badge, this.compact = false});

  final ProductBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pair = context.zb.badge(badge.type);
    final icon = badge.icon;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: pair.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && icon.isNotEmpty) ...[
            Text(icon, style: TextStyle(fontSize: compact ? 9 : 11)),
            const SizedBox(width: 4),
          ],
          Text(
            badge.label,
            style: (compact ? context.tt.labelSmall : context.tt.labelMedium)?.copyWith(
              color: pair.fg,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
