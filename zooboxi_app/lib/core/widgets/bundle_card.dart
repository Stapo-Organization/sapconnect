import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../analytics/events_buffer.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';
import 'press_scale.dart';
import 'price_text.dart';
import 'section_header.dart';
import 'zb_image.dart';

/// The «بكج» card — deliberately NOT the standard product card.
///
/// The composed collage artwork is the hero and is shown WHOLE, with nothing
/// laid over it: it already carries its own coral «مجاناً» seal, and a badge
/// in that corner would only cover it — which is exactly why the card used to
/// look worse in the app than on the website. Everything else — the express
/// chip, the gift line, the savings chip, the price against the struck sum,
/// and the add button — lives in the body below, drawn in crisp native type.
class BundleCardView extends ConsumerWidget {
  const BundleCardView({
    super.key,
    required this.product,
    this.onAdd,
    this.width,
    this.zone,
  });

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;
  final double? width;
  final String? zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final tag = product.bundle;
    final discount = product.discountPercent;
    final express = tag?.stockClass == 'express';

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The composed artwork, shown WHOLE and unobstructed — exactly the
          // picture the website shows. Nothing is laid over it: the seal it
          // already carries says «مجاناً» far better than a second pill, and
          // an overlay in that corner would simply cover the seal. Its own
          // light ground is repeated behind it, so `contain` never letterboxes
          // visibly whatever height the row hands us.
          Expanded(
            child: ColoredBox(
              color: _artworkGround,
              child: ZbImage(url: product.image, fit: BoxFit.contain),
            ),
          ),

          // ── the deal body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (express)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: _chip(
                          context,
                          '⚡ ${product.deliveryChip?.label ?? l.bundleExpressChip}',
                          fg: cs.primary,
                          bg: cs.primaryContainer.withValues(alpha: .6),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        tag?.giftLine != null
                            ? '🎁 ${tag!.giftLine}'
                            : (tag != null && tag.pieces > 1
                                ? l.bundlePiecesLine(tag.pieces)
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: tag?.giftLine != null
                              ? cs.error
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (discount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _chip(
                                context,
                                l.bundleSavePercent(discount),
                                fg: Colors.white,
                                bg: cs.error,
                              ),
                            ),
                          PriceText(
                            price: product.price,
                            regularPrice: product.regularPrice,
                            onSale: product.onSale,
                            style: context.tt.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    _AddBundleButton(product: product, onAdd: onAdd),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: product.name,
      child: PressScale(
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
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
    );
  }

  /// The composed artwork's own ground, repeated behind it so a `contain`
  /// fit shows the whole picture without a visible letterbox.
  static const Color _artworkGround = Color(0xFFF4F7F6);

  Widget _chip(BuildContext context, String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: context.tt.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

/// The add control: a filled teal pill that briefly celebrates a successful
/// add. Bundles are simple products by construction, so this never needs the
/// "choose a variant" detour.
class _AddBundleButton extends ConsumerStatefulWidget {
  const _AddBundleButton({required this.product, required this.onAdd});

  final ProductCard product;
  final Future<bool> Function(ProductCard product)? onAdd;

  @override
  ConsumerState<_AddBundleButton> createState() => _AddBundleButtonState();
}

class _AddBundleButtonState extends ConsumerState<_AddBundleButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    if (onAdd == null) {
      unawaited(context.push('/product/${widget.product.id}', extra: widget.product));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await onAdd(widget.product);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    if (ok) {
      unawaited(Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _done = false);
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final enabled = widget.product.inStock && !_busy;

    return AnimatedContainer(
      duration: Motion.select,
      height: 40,
      width: 44,
      decoration: BoxDecoration(
        color: _done ? cs.tertiary : cs.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? _add : null,
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _done ? Icons.check_rounded : Icons.shopping_bag_outlined,
                    size: 21,
                    color: Colors.white,
                  ).animate(key: ValueKey(_done)).scale(
                      begin: const Offset(.7, .7),
                      end: const Offset(1, 1),
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                    ),
          ),
        ),
      ),
    );
  }
}

/// The bundles rail — bigger cards than the standard rail, because the
/// artwork IS the pitch and it deserves the room.
class BundleRailView extends ConsumerWidget {
  const BundleRailView({
    super.key,
    required this.title,
    required this.products,
    this.onSeeAll,
    this.onAdd,
    this.zone,
  });

  final String title;
  final List<ProductCard> products;
  final VoidCallback? onSeeAll;
  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;

  static const double _cardWidth = 236;
  /// Name (2 lines) + chip row + savings chip + price + compare line. Shared
  /// with the «عرض الكل» grid so a rail card and a grid card are the same card.
  static const double bodyHeight = 156;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final stagger = !context.reduceMotion;
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        const SizedBox(height: 12),
        SizedBox(
          height: _cardWidth + scale.scale(bodyHeight),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = SizedBox(
                width: _cardWidth,
                child: BundleCardView(
                  product: products[index],
                  onAdd: onAdd,
                  zone: zone,
                ),
              );
              if (!stagger) return card;
              return card
                  .animate()
                  .fadeIn(
                    duration: 260.ms,
                    delay: Motion.stagger * index.clamp(0, 6),
                    curve: Curves.easeOut,
                  )
                  .moveX(begin: 16, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
            },
          ),
        ),
      ],
    );
  }
}
