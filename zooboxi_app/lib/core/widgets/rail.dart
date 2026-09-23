import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../characters/characters.dart';
import '../characters/companion.dart';
import '../motion/motion.dart';
import 'press_scale.dart';
import 'product_card.dart';
import 'product_card_metrics.dart';
import 'section_header.dart';

/// A horizontal strip of product cards under a title.
///
/// Cards stagger in on first paint — 45ms apart, which reads as the row
/// arriving rather than as three separate animations. Under Reduce Motion they
/// simply appear.
class ProductRailView extends ConsumerWidget {
  const ProductRailView({
    super.key,
    required this.title,
    required this.products,
    this.subtitle,
    this.onSeeAll,
    this.onAdd,
    this.cardWidth = ProductCardMetrics.railCardWidth,
    this.zone,
    this.animate = true,
  });

  final String title;
  final String? subtitle;
  final List<ProductCard> products;
  final VoidCallback? onSeeAll;
  final Future<bool> Function(ProductCard product)? onAdd;
  final double cardWidth;
  final String? zone;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    final stagger = animate && !context.reduceMotion;
    final look = ShelfLook.maybeOf(context);
    final endCard = (look?.endCard ?? false) && onSeeAll != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, onSeeAll: onSeeAll),
        const SizedBox(height: 12),
        SizedBox(
          // Same slot math as the grid, so a rail card and a grid card are
          // literally the same card at the same size.
          height: ProductCardMetrics.height(context, cardWidth),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: products.length + (endCard ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == products.length) {
                return RailEndCard(
                  width: cardWidth * 0.84,
                  onTap: onSeeAll!,
                  peek: look?.endPeek ?? false,
                );
              }
              final card = SizedBox(
                width: cardWidth,
                child: ProductCardView(
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

/// Where a rail ends: «شوف الكل», instead of the row just stopping. On one
/// rail of the page the customer's animal leans in from the far edge — found
/// only by those who scroll to the end, which is the whole charm of it.
class RailEndCard extends StatelessWidget {
  const RailEndCard({super.key, required this.width, required this.onTap, this.peek = false});

  final double width;
  final VoidCallback onTap;
  final bool peek;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final rtl = context.isRtl;
    final wash = context.isDark ? cs.primaryContainer : ZbTokens.tealTint;
    final ink = context.isDark ? cs.onPrimaryContainer : ZbTokens.tealDeep;
    return Semantics(
      button: true,
      label: l.railEndTitle,
      child: PressScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Container(
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(ZbTokens.rLg)),
          child: Stack(
            children: [
              PositionedDirectional(
                top: 16,
                start: 14,
                end: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.railEndKicker,
                      style: context.tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.railEndTitle,
                      style: context.tt.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 12,
                bottom: 12,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Icon(
                    rtl ? Icons.keyboard_arrow_left_rounded : Icons.keyboard_arrow_right_rounded,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              // The peek's cut edge sits on the card's far edge, so the card
              // itself is the wall the animal leans out from behind.
              if (peek)
                Positioned(
                  left: rtl ? 0 : null,
                  right: rtl ? null : 0,
                  bottom: 0,
                  child: Companion(
                    ZbPose.peekSide,
                    fallback: ZbCast.dog,
                    height: 104,
                    flip: rtl,
                    idle: ZbIdle.peek,
                    entrance: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
