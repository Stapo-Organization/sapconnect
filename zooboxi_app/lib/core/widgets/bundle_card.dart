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
/// The composed collage artwork (teal ground, starburst seal, deal math) is
/// the hero and runs full-bleed; the body underneath carries the essentials a
/// deal needs — savings pill, gift line, price against the struck sum, and a
/// wide add button — on a teal-washed base so the card reads as an offer the
/// moment it scrolls into view.
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
        border: Border.all(color: cs.primary.withValues(alpha: .28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: .10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── the collage artwork, full-bleed ──
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ZbImage(url: product.image, fit: BoxFit.cover),
                if (discount > 0)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: _pill(
                      context,
                      l.bundleSavePercent(discount),
                      bg: cs.error,
                      fg: Colors.white,
                    ),
                  ),
                if (express)
                  PositionedDirectional(
                    bottom: 10,
                    start: 10,
                    child: _pill(
                      context,
                      '⚡ ${product.deliveryChip?.label ?? l.bundleExpressChip}',
                      bg: Colors.black.withValues(alpha: .55),
                      fg: Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          // ── the deal body ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: .35),
            ),
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
                const SizedBox(height: 4),
                if (tag?.giftLine != null)
                  Text(
                    '🎁 ${tag!.giftLine}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (tag != null && tag.pieces > 1)
                  Text(
                    l.bundlePiecesLine(tag.pieces),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PriceText(
                        price: product.price,
                        regularPrice: product.regularPrice,
                        onSale: product.onSale,
                        style: context.tt.titleMedium,
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

  Widget _pill(BuildContext context, String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: context.tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800),
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
  static const double _bodyHeight = 128;

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
          height: _cardWidth + scale.scale(_bodyHeight),
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
