import 'package:flutter/material.dart';

import '../../features/catalog/data/product_models.dart';
import 'product_card.dart';
import 'product_card_metrics.dart';
import 'section_header.dart';

/// A shelf, laid out as a shelf.
///
/// The rails elsewhere are a magazine: a strip of six, a headline, another
/// strip. That is right for a 6,000-SKU store someone is browsing. إكسبريس is
/// not being browsed — it is a thousand things that can be at the door in two
/// hours, and the customer is looking for one of them. So it gets the grid
/// every quick-commerce app uses: two columns, no horizontal scrolling, the
/// whole shelf in front of you.
///
/// It is a sliver, not a box in a sliver, so the cards build as they are
/// reached instead of all at once — and `SliverGrid` hands each one its own
/// repaint boundary, which the adapters around it do not.
class ProductGridSliver extends StatelessWidget {
  const ProductGridSliver({
    super.key,
    required this.products,
    this.title,
    this.onAdd,
    this.zone,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<ProductCard> products;

  /// Rendered above the grid when the server sent one with the rail.
  final String? title;

  final Future<bool> Function(ProductCard product)? onAdd;
  final String? zone;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCardView(
            product: products[index],
            onAdd: onAdd,
            zone: zone,
          ),
          childCount: products.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: ProductCardMetrics.gridSpacing,
          crossAxisSpacing: ProductCardMetrics.gridSpacing,
          mainAxisExtent: ProductCardMetrics.gridExtent(
            context,
            horizontalPadding: padding.horizontal,
          ),
        ),
      ),
    );
  }

  /// The grid's own heading, emitted as a separate sliver above it so the
  /// grid itself stays a pure grid.
  static Widget? heading(String? title, {VoidCallback? onSeeAll}) =>
      (title == null || title.isEmpty)
          ? null
          : SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionHeader(title: title, onSeeAll: onSeeAll),
              ),
            );
}
