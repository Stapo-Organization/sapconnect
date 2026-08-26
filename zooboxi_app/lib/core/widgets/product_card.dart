import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../analytics/events_buffer.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import 'badge_chip.dart';
import 'delivery_chip.dart';
import 'press_scale.dart';
import 'price_text.dart';
import 'product_card_foot.dart';
import 'product_card_metrics.dart';
import 'wishlist_heart.dart';
import 'zb_image.dart';

/// The product card, used by every grid and rail in the app.
///
/// Every row of cards lines up because the card is built from the fixed slots
/// in [ProductCardMetrics] — brand, a name that is *always* two lines tall, a
/// price line, an info line, and the add control — rather than from whatever
/// its content measures. The parent asks the same class for its height, so the
/// card and the box it is given are computed from one source and can never
/// disagree by the pixel that shows an overflow stripe.
///
/// Text scaling is clamped here to the same ceiling the metrics assume, which
/// is what makes that guarantee hold at 200% type as well as at 100%.
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
  final Future<bool> Function(ProductCard product)? onAdd;

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
        border: Border.all(color: cs.outlineVariant, width: ProductCardMetrics.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The body takes exactly what its slots need; the image takes what
          // is left. If the box we were handed differs from the computed
          // height by a pixel — a rounded grid extent, a scrollbar — that
          // pixel lands on the artwork, where nobody can see it, instead of
          // on a control, where it would clip.
          Expanded(
            child: _Media(product: product, onAdd: onAdd, outOfStock: outOfStock),
          ),
          SizedBox(
            height: ProductCardMetrics.bodyHeight(context),
            child: Padding(
              padding: const EdgeInsets.all(ProductCardMetrics.bodyPadding),
              child: _Body(product: product),
            ),
          ),
        ],
      ),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ProductCardMetrics.maxTextScale,
      child: Semantics(
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
          child: card,
        ),
      ),
    );
  }
}

/// The image block and everything that floats over it.
class _Media extends StatelessWidget {
  const _Media({
    required this.product,
    required this.onAdd,
    required this.outOfStock,
  });

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final bool outOfStock;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final badge = product.badge;
    final discount = product.discountPercent;

    final image = ZbImage(url: product.image, padding: const EdgeInsets.all(10));

    return DecoratedBox(
      // A hairline under the image gives the card structure in light mode,
      // where the near-white image ground and the white body would otherwise
      // melt into one another.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sold out reads as "dimmed", not as "broken": the art stays
          // recognisable, it just stops competing with what is buyable.
          outOfStock ? Opacity(opacity: 0.4, child: image) : image,

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
            child: WishlistHeart(
              productId: product.id,
              seeded: product.wishlisted,
              size: 32,
            ),
          ),

          if (outOfStock)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.inverseSurface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                ),
                child: Text(
                  l.cardOutOfStock,
                  style: context.tt.labelSmall?.copyWith(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // The add control lives ON the artwork (the owner's call — it keeps
          // the body to pure information and the action where the eye already
          // is). Bottom-end: clear of the badge stack and the OOS chip.
          if (!outOfStock)
            PositionedDirectional(
              bottom: 6,
              end: 6,
              child: ProductCardAddOverlay(product: product, onAdd: onAdd),
            ),
        ],
      ),
    );
  }
}

/// The slot stack under the image.
class _Body extends StatelessWidget {
  const _Body({required this.product});

  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final brand = product.brand?.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The brand slot is reserved whether or not there is a brand: an
        // unbranded card must still end where its neighbour does.
        SizedBox(
          height: ProductCardMetrics.brandSlot(context),
          width: double.infinity,
          child: brand == null || brand.isEmpty
              ? null
              : Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
        const SizedBox(height: ProductCardMetrics.gapBrandName),
        SizedBox(
          height: ProductCardMetrics.nameSlot(context),
          width: double.infinity,
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: ProductCardMetrics.gapNamePrice),
        // Any rounding slack between the computed height and the box we were
        // actually given lands here, so it never squeezes a slot.
        const Spacer(),
        _PriceLine(product: product),
        const SizedBox(height: ProductCardMetrics.gapPriceChip),
        _InfoLine(product: product),
      ],
    );
  }
}

/// Price, "starts from" prefix and the struck-through original — one line,
/// scaled down rather than wrapped, because a price that wraps stops being a
/// price and becomes two numbers.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product});

  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final regular = product.regularPrice;
    final showCompare = product.onSale && regular != null && regular > product.price;

    final priceStyle = (context.tt.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    );

    return SizedBox(
      height: ProductCardMetrics.priceSlot(context),
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product.priceFrom) ...[
              Text(
                l.priceFrom,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Gap.w4,
            ],
            Text.rich(_money(product.price, priceStyle, locale), maxLines: 1),
            if (showCompare) ...[
              Gap.w6,
              Text.rich(
                _money(
                  regular,
                  (context.tt.bodySmall ?? const TextStyle()).copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: cs.onSurfaceVariant,
                  ),
                  locale,
                ),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The Riyal glyph carries more optical weight than the digits at the same
  /// point size, so it is nudged down to sit level — the same treatment
  /// [PriceText] gives it on every other surface.
  TextSpan _money(double value, TextStyle style, String locale) => TextSpan(
    style: style,
    children: [
      TextSpan(text: Fmt.number(value, locale: locale)),
      const TextSpan(text: ' '),
      TextSpan(
        text: riyalSymbol,
        style: style.copyWith(fontSize: (style.fontSize ?? 15) * 0.86),
      ),
    ],
  );
}

/// One line of signal: how fast it reaches you, or how little is left.
///
/// Scarcity wins when both are true. "Only 3 left" moves a basket in a way a
/// delivery promise does not, and two chips on a card this size is clutter.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.product});

  final ProductCard product;

  static const int _scarcityThreshold = 5;

  @override
  Widget build(BuildContext context) {
    final qty = product.stockQty;
    final scarce = product.inStock && qty != null && qty > 0 && qty <= _scarcityThreshold;
    final chip = product.deliveryChip;

    return SizedBox(
      height: ProductCardMetrics.chipSlot(context),
      width: double.infinity,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: scarce
            ? _Scarcity(count: qty)
            : (chip == null
                  ? const SizedBox.shrink()
                  : DeliveryChipView(chip: chip, compact: true)),
      ),
    );
  }
}

class _Scarcity extends StatelessWidget {
  const _Scarcity({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final amber = context.zb.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: amber, shape: BoxShape.circle),
        ),
        Gap.w6,
        Flexible(
          child: Text(
            L.of(context).cardStockLeft(count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(color: amber, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
