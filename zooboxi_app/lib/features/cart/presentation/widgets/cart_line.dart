import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/delivery_chip.dart';
import '../../../../core/widgets/qty_stepper.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../features/catalog/data/product_models.dart' show DeliveryChip;
import '../../../../l10n/app_localizations.dart';
import '../../data/cart_controller.dart';
import '../../data/cart_models.dart';
import 'gift_cart_line.dart';

/// One cart line: image, name, variant, per-line fulfilment note, stepper.
/// Swiping it away removes it — with the tap-to-remove path still on the
/// stepper's minus at quantity 1, because swipe is discoverable-only.
class CartLineView extends ConsumerWidget {
  const CartLineView({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A gift is a different contract: locked quantity, no price, and removing
    // it releases a reward rather than deleting a product. It gets its own
    // line rather than a pile of `if (isGift)` inside this one.
    if (item.isGift) {
      final grantId = item.grantId;
      return GiftCartLineView(
        item: item,
        onRemove: grantId == null ? null : () => _release(context, ref, grantId),
      );
    }

    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final fulfillment = item.fulfillment;

    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: _DismissBackground(label: l.actionRemove),
      onDismissed: (_) => _remove(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/product/${item.productId}'),
              child: SizedBox(
                width: 76,
                height: 76,
                child: ZbImage(
                  url: item.image,
                  radius: BorderRadius.circular(ZbTokens.rSm),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if ((item.attributesLabel ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.attributesLabel!,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  if (fulfillment != null && (fulfillment.headline ?? '').isNotEmpty) ...[
                    Gap.h8,
                    DeliveryChipView(
                      chip: chipFrom(fulfillment),
                      compact: true,
                    ),
                  ],
                  if (fulfillment != null && fulfillment.isSplit && fulfillment.shortfall > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.cartShortfall(fulfillment.shortfall),
                        style: context.tt.labelSmall?.copyWith(color: context.zb.warning),
                      ),
                    ),
                  Gap.h8,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.price(item.lineTotal, locale: locale),
                          style: context.tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      QtyStepper(
                        value: item.qty,
                        max: item.maxReachable,
                        dense: true,
                        onChanged: (value) =>
                            ref.read(cartControllerProvider.notifier).setQuantity(item.key, value),
                        onRemove: () => _remove(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands the reward back. The claim lives in the WooCommerce session, so
  /// this is a loyalty call — deleting the cart line would leave the grant
  /// stuck in `claimed` with nothing to show for it.
  Future<void> _release(BuildContext context, WidgetRef ref, int grantId) async {
    final l = L.of(context);
    Haptics.light();
    try {
      await ref.read(cartControllerProvider.notifier).releaseGrant(grantId);
      if (!context.mounted) return;
      AppToast.info(context, l.cartItemRemoved);
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, l.rewardClaimFailed);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    Haptics.light();
    try {
      await ref.read(cartControllerProvider.notifier).remove(item.key);
      if (!context.mounted) return;
      AppToast.info(context, l.cartItemRemoved);
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, l.cartUpdateFailed);
    }
  }
}

/// Builds a delivery chip out of a line's fulfilment note, so cart lines use
/// the same tier vocabulary and colours as product cards.
DeliveryChip chipFrom(LineFulfillment fulfillment) => DeliveryChip(
      tier: fulfillment.tier ?? 'shipping',
      label: fulfillment.headline ?? '',
    );

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 22),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: cs.error),
          Gap.w8,
          Text(label, style: context.tt.labelMedium?.copyWith(color: cs.error)),
        ],
      ),
    );
  }
}
