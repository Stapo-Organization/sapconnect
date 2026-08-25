import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/product_card_metrics.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/product_models.dart';
import '../data/account_repository.dart';

/// "اطلبها مجددًا" — everything this customer has actually bought.
///
/// It is a plain product grid on purpose: these are known-good products, so
/// the fastest thing the screen can do is get out of the way and let the
/// add-to-cart button work.
class BuyAgainScreen extends ConsumerWidget {
  const BuyAgainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final products = ref.watch(buyAgainProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.buyAgainTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(buyAgainProvider);
          await ref.read(buyAgainProvider.future);
        },
        child: AsyncView<List<ProductCard>>(
          value: products,
          onRetry: () => ref.invalidate(buyAgainProvider),
          skeleton: const SkeletonProductGrid(count: 4),
          builder: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.replay_rounded,
                title: l.buyAgainEmpty,
                message: l.buyAgainEmptyHint,
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
              itemCount: list.length,
              itemBuilder: (context, index) => ProductCardView(
                product: list[index],
                zone: 'buy_again',
                onAdd: (product) =>
                    addToCart(context, ref, product: product, zone: 'buy_again'),
              ),
            );
          },
        ),
      ),
    );
  }
}
