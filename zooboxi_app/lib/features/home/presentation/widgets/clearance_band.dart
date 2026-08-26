import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/rail.dart';
import '../../../catalog/data/product_models.dart';

/// Clearance, set apart from the rails around it.
///
/// A discount rail that looks like every other rail is just another rail. The
/// tinted band is the cheapest possible signal that these prices are different
/// — a wash of the sale accent, not a red screen: the accent stays rare enough
/// that it still means something when it appears on a card.
class ClearanceBand extends StatelessWidget {
  const ClearanceBand({
    super.key,
    required this.title,
    required this.products,
    this.onAdd,
  });

  final String title;
  final List<ProductCard> products;
  final Future<bool> Function(ProductCard product)? onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final sale = context.zb.sale;
    final dark = context.isDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sale.withValues(alpha: dark ? 0.16 : 0.10),
            sale.withValues(alpha: dark ? 0.05 : 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ProductRailView(
          title: title,
          products: products,
          zone: 'clearance',
          onAdd: onAdd,
          onSeeAll: () => context.push(
            Uri(
              path: '/listing',
              queryParameters: {'rail': 'clearance', 'title': title},
            ).toString(),
          ),
        ),
      ),
    );
  }
}
