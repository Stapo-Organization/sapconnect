import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/paginated_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../data/product_models.dart';

/// «البكجات» — every live bundle, in the order the server ranked them for
/// THIS viewer: their pets' species first, then a bundle of a staple that is
/// about to run out, then what their nearest branch can hand them in two
/// hours. The list is one page by construction (a handful of curated bundles,
/// not a catalogue), so the grid's paging simply never asks for page 2.
final bundlesProvider = FutureProvider.autoDispose<List<ProductCard>>(
  (ref) => ref.watch(catalogRepositoryProvider).bundles(),
);

class BundlesScreen extends ConsumerWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.bundlesTitle)),
      body: PaginatedProductGrid(
        resetKey: 'bundles',
        zone: 'bundles',
        fetchPage: (page) async {
          final products =
              page > 1 ? const <ProductCard>[] : await ref.read(bundlesProvider.future);
          return ListingResult(
            products: products,
            total: products.length,
            pages: 1,
            page: 1,
          );
        },
        onAdd: (product) => addToCart(
          context,
          ref,
          product: product,
          zone: 'bundles',
          quiet: true,
        ),
        emptyState: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: l.bundlesEmpty,
          message: l.bundlesEmptyHint,
          mascot: true,
        ),
      ),
    );
  }
}
