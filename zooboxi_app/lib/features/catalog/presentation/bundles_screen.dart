import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/bundle_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../data/catalog_repository.dart';
import '../data/product_models.dart';

/// «البكجات» — every live bundle, in the order the server ranked them for
/// THIS viewer: their pets' species first, then a bundle of a staple that is
/// about to run out, then what their nearest branch can hand them in two
/// hours. A single curated page by construction — no paging, no filters,
/// just the deals in their big cards.
final bundlesProvider = FutureProvider.autoDispose<List<ProductCard>>(
  (ref) => ref.watch(catalogRepositoryProvider).bundles(),
);

class BundlesScreen extends ConsumerWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final bundles = ref.watch(bundlesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.bundlesTitle)),
      body: bundles.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          gridDelegate: _delegate(context),
          itemCount: 4,
          itemBuilder: (_, _) => const SkeletonBox(),
        ),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(bundlesProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l.bundlesEmpty,
              message: l.bundlesEmptyHint,
              mascot: true,
            );
          }
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(bundlesProvider);
              await ref.read(bundlesProvider.future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: _delegate(context),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final card = BundleCardView(
                  product: products[index],
                  zone: 'bundles',
                  onAdd: (product) => addToCart(
                    context,
                    ref,
                    product: product,
                    zone: 'bundles',
                    quiet: true,
                  ),
                );
                if (context.reduceMotion) return card;
                return card
                    .animate()
                    .fadeIn(
                      duration: 260.ms,
                      delay: Motion.stagger * (index % 6),
                      curve: Curves.easeOut,
                    )
                    .slideY(begin: .04, end: 0, duration: 260.ms);
              },
            ),
          );
        },
      ),
    );
  }

  /// Two columns of the same card the rail draws, body height scaled with
  /// the reader's text size so nothing clips at accessibility scales.
  SliverGridDelegate _delegate(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    final width = (MediaQuery.sizeOf(context).width - 16 * 2 - 12) / 2;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: width + scale.scale(BundleRailView.bodyHeight),
    );
  }
}
