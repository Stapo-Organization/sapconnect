import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../analytics/events_buffer.dart';
import '../utils/haptics.dart';
import 'badge_chip.dart';
import 'delivery_chip.dart';
import 'price_text.dart';
import 'press_scale.dart';
import 'qty_stepper.dart';
import 'wishlist_heart.dart';
import 'zb_image.dart';

/// The product card, used by every grid and rail in the app.
///
/// The layout is deliberately fixed-height in its lower half so a grid of
/// cards lines up: image square on top, then brand, a two-line name, price,
/// delivery promise, and the add control. A card whose name wraps to one line
/// still ends at the same baseline as its neighbour.
class ProductCardView extends ConsumerWidget {
  const ProductCardView({
    super.key,
    required this.product,
    this.onAdd,
    this.width,
    this.zone,
  });

  final ProductCard product;

  /// Supplied by screens that own an add-to-cart action. Variable products
  /// always open the page instead — a variant has to be chosen first.
  final Future<void> Function(ProductCard product)? onAdd;

  final double? width;

  /// Merchandising slot this card was rendered in, forwarded with the click
  /// event so the server can attribute the visit.
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final outOfStock = !product.inStock;

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Media(product: product, outOfStock: outOfStock),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: _Body(product: product, onAdd: onAdd, outOfStock: outOfStock),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: product.name,
      child: PressScale(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        haptic: Haptics.light,
        onTap: () {
          ref.track(ZbEvent(
            type: ZbEvents.view,
            itemCode: product.itemCode,
            zone: zone,
          ));
          context.push('/product/${product.id}', extra: product);
        },
        child: outOfStock
            ? Opacity(opacity: 0.72, child: card)
            : card,
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.product, required this.outOfStock});

  final ProductCard product;
  final bool outOfStock;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final badge = product.badge;
    final discount = product.discountPercent;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ZbImage(url: product.image, padding: const EdgeInsets.all(10)),

          // Badge and discount stack in the top-start corner, away from the
          // heart so a long badge never collides with it.
          PositionedDirectional(
            top: 8,
            start: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) BadgeChip(badge: badge, compact: true),
                if (discount > 0) ...[
                  if (badge != null) const SizedBox(height: 4),
                  DiscountPill(percent: discount),
                ],
              ],
            ),
          ),

          PositionedDirectional(
            top: 4,
            end: 4,
            child: WishlistHeart(productId: product.id, seeded: product.wishlisted),
          ),

          if (outOfStock)
            PositionedDirectional(
              bottom: 8,
              start: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.cs.inverseSurface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.pdpOutOfStock,
                  style: context.tt.labelSmall?.copyWith(color: context.cs.onInverseSurface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.product, required this.onAdd, required this.outOfStock});

  final ProductCard product;
  final Future<void> Function(ProductCard product)? onAdd;
  final bool outOfStock;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _busy = false;

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    if (onAdd == null || _busy) return;

    // A variable product can't be added blind — the customer has to pick a
    // flavour or size first, so send them to the page instead of guessing.
    if (widget.product.isVariable) {
      unawaited(context.push('/product/${widget.product.id}', extra: widget.product));
      return;
    }

    setState(() => _busy = true);
    try {
      await onAdd(widget.product);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cs = context.cs;
    final brand = product.brand?.name;
    final chip = product.deliveryChip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand != null && brand.isNotEmpty)
          Text(
            brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        const SizedBox(height: 2),
        // Fixed two lines: the grid stays aligned whether a name wraps or not.
        SizedBox(
          height: (context.tt.bodySmall?.fontSize ?? 12) * 1.5 * 2,
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        const Spacer(),
        if (chip != null) ...[
          DeliveryChipView(chip: chip, compact: true),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PriceText(
                price: product.price,
                regularPrice: product.regularPrice,
                onSale: product.onSale,
                priceFrom: product.priceFrom,
                style: context.tt.titleSmall,
              ),
            ),
            if (widget.onAdd != null)
              AddButton(
                onTap: _add,
                enabled: !widget.outOfStock,
                busy: _busy,
              ),
          ],
        ),
      ],
    );
  }
}

