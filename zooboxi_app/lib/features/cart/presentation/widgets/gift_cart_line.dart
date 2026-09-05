import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/presentation/widgets/reward_glyph.dart';
import '../../data/cart_models.dart';

/// A claimed reward sitting in the basket.
///
/// It is a real line — it picks, it ships, it leaves stock — so it keeps the
/// shape of every other line. What it loses is the two controls that would be
/// lies: there is no quantity to change, and no price to read. Removing it
/// doesn't delete a product, it hands the reward back, which is why the action
/// is a plain «×» rather than a bin.
class GiftCartLineView extends StatelessWidget {
  const GiftCartLineView({
    super.key,
    required this.item,
    this.onRemove,
    this.busy = false,
  });

  final CartItem item;

  /// Releases the claim. Null while there is nothing sensible to release to.
  final VoidCallback? onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: zb.sale.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: ZbImage(
              url: item.image,
              radius: BorderRadius.circular(ZbTokens.rSm),
              padding: const EdgeInsets.all(6),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Gap.w8,
                    const _GiftChip(),
                  ],
                ),
                if ((item.attributesLabel ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.attributesLabel!,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                Gap.h8,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.rewardGiftFree,
                        style: context.tt.titleSmall?.copyWith(
                          color: zb.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (onRemove != null)
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: cs.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        tooltip: l.rewardRemove,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftChip extends StatelessWidget {
  const _GiftChip();

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: zb.sale.withValues(alpha: context.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RewardGlyph(kind: 'gift_product', size: 13),
          Gap.w4,
          Text(
            L.of(context).rewardGiftChip,
            style: context.tt.labelSmall?.copyWith(
              color: zb.sale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
