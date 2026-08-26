import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/product_card_metrics.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/product_models.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../../../core/session/session_controller.dart';

/// The saved-products grid.
///
/// Guests see a sign-in prompt rather than an empty list, because an empty
/// wishlist and "your wishlist lives on your account" are different messages
/// and only one of them is actionable.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final authed = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.wishlistTitle)),
      body: !authed
          ? EmptyState(
              icon: Icons.favorite_rounded,
              title: l.wishlistEmpty,
              message: l.authRequiredWishlist,
              actionLabel: l.accountLogin,
              onAction: () => showAuthSheet(context, reason: l.authRequiredWishlist),
            )
          : const _List(),
    );
  }
}

class _List extends ConsumerWidget {
  const _List();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final products = ref.watch(wishlistProductsProvider);
    // Un-hearting removes the card immediately; the server list is only
    // re-fetched when the screen is re-entered.
    final wishlisted = ref.watch(wishlistControllerProvider);

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(wishlistProductsProvider);
        await ref.read(wishlistProductsProvider.future);
      },
      child: AsyncView<List<ProductCard>>(
        value: products,
        onRetry: () => ref.invalidate(wishlistProductsProvider),
        skeleton: const SkeletonProductGrid(count: 4),
        builder: (all) {
          final visible = all.where((p) => wishlisted.contains(p.id)).toList();
          if (visible.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: l.wishlistEmpty,
              message: l.wishlistEmptyHint,
              actionLabel: l.cartStartShopping,
              onAction: () => context.go('/home'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: ProductCardMetrics.gridSpacing,
              crossAxisSpacing: ProductCardMetrics.gridSpacing,
              mainAxisExtent: ProductCardMetrics.gridExtent(context),
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) => ProductCardView(
              product: visible[index],
              zone: 'wishlist',
              onAdd: (product) =>
                  addToCart(context, ref, product: product, zone: 'wishlist', quiet: true),
            ),
          );
        },
      ),
    );
  }
}
