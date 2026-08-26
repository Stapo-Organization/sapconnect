import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/rail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/animal_nav.dart';
import 'widgets/brand_strip.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/home_header.dart';

/// The storefront. Everything above the fold answers one question — "what can
/// I get, and how fast" — so the location chip sits in the header and every
/// card carries its own delivery promise.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async {
            Haptics.light();
            ref.invalidate(homeProvider);
            await ref.read(homeProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: HomeHeader()),
              if (home.hasValue)
                ..._content(context, ref, home.requireValue)
              else if (home.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    error: home.error,
                    onRetry: () => ref.invalidate(homeProvider),
                  ),
                )
              else
                const SliverToBoxAdapter(child: _HomeSkeleton()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, HomePayload payload) {
    // Hearts settle on the first frame instead of popping in a beat later.
    // Deferred past build: seeding writes to a provider that the hearts on
    // this very screen are watching.
    final allCards = payload.rails.expand((rail) => rail.products).toList();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wishlistControllerProvider.notifier).seedFrom(allCards),
    );

    Future<bool> add(ProductCard product) =>
        addToCart(context, ref, product: product, zone: 'home', quiet: true);

    return [
      if (payload.hero.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: HeroCarousel(slides: payload.hero, campaigns: payload.campaigns),
          ),
        ),
      if (payload.animalNav.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: AnimalNav(items: payload.animalNav),
          ),
        ),
      for (final rail in payload.rails)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ProductRailView(
              title: rail.title,
              products: rail.products,
              zone: rail.key,
              onAdd: add,
              onSeeAll: () => context.push(
                Uri(
                  path: '/listing',
                  queryParameters: {'title': rail.title, 'rail': rail.key},
                ).toString(),
              ),
            ),
          ),
        ),
      if (payload.brands.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BrandStrip(brands: payload.brands),
          ),
        ),
    ];
  }

}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerGroup(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: SkeletonBox(
              width: double.infinity,
              height: MediaQuery.sizeOf(context).width * 0.44,
              radius: ZbTokens.rLg,
            ),
          ),
        ),
        ShimmerGroup(
          child: SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, _) => Gap.w16,
              itemBuilder: (_, _) => const Column(
                children: [
                  SkeletonBox.circle(size: 62),
                  SizedBox(height: 8),
                  SkeletonBox(width: 44, height: 9),
                ],
              ),
            ),
          ),
        ),
        Gap.h24,
        const SkeletonRail(),
        Gap.h24,
        const SkeletonRail(),
      ],
    );
  }
}
