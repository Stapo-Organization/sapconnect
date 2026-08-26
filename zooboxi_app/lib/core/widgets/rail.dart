import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/product_models.dart';
import '../motion/motion.dart';
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
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
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
