import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/rail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../cart/presentation/widgets/free_shipping_bar.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/animal_nav.dart';
import 'widgets/brand_strip.dart';
import 'widgets/campaign_banner.dart';
import 'widgets/clearance_band.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/home_header.dart';
import 'widgets/trust_strip.dart';

/// The storefront.
///
/// The page is **server-merchandised**: `/home` ships an ordered list of slots
/// and this screen renders them in that order, skipping any `type` it doesn't
/// know. That is what lets clearance move above the new arrivals for a weekend
/// without an app release — and what lets the server ship a slot before the app
/// that draws it exists.
///
/// Everything above the fold still answers one question — "what can I get, and
/// how fast" — so the location chip sits in the header and every card carries
/// its own delivery promise.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// True once the hero canvas has scrolled away from under the status bar —
  /// the clock flips back from light to the theme's own color.
  bool _pastCanvas = false;

  /// Roughly where the canvas stops backing the status bar. An estimate is
  /// fine: the flip happens mid-scroll, never at rest.
  double _canvasThreshold = 320;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final past = notification.metrics.pixels > _canvasThreshold;
    if (past != _pastCanvas) setState(() => _pastCanvas = past);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final home = ref.watch(homeProvider);

    // Stale-while-revalidate. Home is the screen the app opens *into*: the
    // last good payload paints on frame one and the refresh lands behind it.
    // A failed refresh therefore leaves a browsable store rather than an error
    // page — the retry only appears when there is genuinely nothing to show.
    final payload = home.value ?? (home.isLoading || home.hasError
        ? ref.watch(homeCacheProvider)
        : null);

    // The canvas unit — colored header + hero fused, HungerStation-style —
    // exists whenever there is a hero to show and the server kept the slot.
    final canvas = payload != null &&
        !payload.isEmpty &&
        HeroCarousel.hasContent(payload) &&
        payload.slots.any((slot) => slot.type == 'hero');

    final width = MediaQuery.sizeOf(context).width;
    final statusTop = MediaQuery.paddingOf(context).top;
    _canvasThreshold =
        (168 + HeroMetrics.height(context, width) + HeroMetrics.dotsBand) * 0.85;

    final scroll = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator.adaptive(
        edgeOffset: canvas ? statusTop + 4 : 0,
        onRefresh: () async {
          Haptics.light();
          ref.invalidate(homeProvider);
          ref.invalidate(homeFeedProvider);
          await ref.read(homeProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (canvas) ...[
              SliverToBoxAdapter(
                child: HeroCarousel(slides: payload.hero, campaigns: payload.campaigns),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ] else
              const SliverToBoxAdapter(child: HomeHeader()),
            if (payload != null && !payload.isEmpty)
              ..._slots(context, ref, payload)
            else if (payload != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: l.homeEmpty,
                  message: l.homeEmptyHint,
                ),
              )
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
    );

    // The canvas runs behind the status bar, so the clock goes light while it
    // is there and returns to the theme's color once it scrolls away.
    final statusStyle = (canvas && !_pastCanvas) || context.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusStyle,
      child: Scaffold(
        body: canvas ? scroll : SafeArea(bottom: false, child: scroll),
      ),
    );
  }

  List<Widget> _slots(BuildContext context, WidgetRef ref, HomePayload payload) {
    final l = L.of(context);

    final feed = ref.watch(homeFeedProvider);
    final feedData = feed.value ??
        (feed.isLoading || feed.hasError ? ref.watch(homeFeedCacheProvider) : null);
    final feedPending = feedData == null && feed.isLoading;

    final wishlist = ref.watch(wishlistProductsProvider).value ?? const <ProductCard>[];
    final freeShipping = ref.watch(cartFreeShippingNudgeProvider);

    // Hearts settle on the first frame instead of popping in a beat later.
    // Deferred past build: seeding writes to a provider that the hearts on
    // this very screen are watching.
    final allCards = <ProductCard>[
      ...payload.rails.expand((rail) => rail.products),
      ...?feedData?.personal.products,
      ...?feedData?.forYou?.products,
      ...?feedData?.inCity?.products,
    ];
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wishlistControllerProvider.notifier).seedFrom(allCards),
    );

    Future<bool> add(ProductCard product) =>
        addToCart(context, ref, product: product, zone: 'home', quiet: true);

    // A campaign shown in the hero is not shown again three rails down.
    final heroIds = heroCampaignsOf(payload.campaigns).map((c) => c.campaignId).toSet();
    final bannerPool = [
      for (final campaign in payload.campaigns)
        if (campaign.inAnyZone(const ['app_banner', 'shop_top']) &&
            !heroIds.contains(campaign.campaignId))
          campaign,
    ];
    var bannerCursor = 0;

    // Cross-slot de-duplication, computed once in layout order. The same
    // product legitimately qualifies as trending *and* a bestseller *and* a
    // recommendation — showing it three times on one screen makes a 6,000-SKU
    // catalogue look like a 12-product one. A rail that loses too much to the
    // slots above it drops out entirely rather than limping on with two cards.
    final shown = <int>{};
    List<ProductCard>? claim(List<ProductCard> products, {int minimum = 3}) {
      final kept = [
        for (final product in products)
          if (!shown.contains(product.id)) product,
      ];
      if (kept.length < minimum) return null;
      shown.addAll(kept.map((product) => product.id));
      return kept;
    }

    final slivers = <Widget>[];
    void emit(Widget child, {double top = 0, double bottom = 24}) => slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: top, bottom: bottom),
              child: child,
            ),
          ),
        );

    for (final slot in payload.slots) {
      switch (slot.type) {
        // The hero fused with the header at the very top of the scroll view —
        // its slot in the layout only decides *whether* it exists, never where:
        // a canvas that starts behind the status bar cannot sit mid-page.
        case 'hero':
          break;

        case 'animal_nav':
          if (payload.animalNav.isEmpty) break;
          emit(AnimalNav(items: payload.animalNav));

        // What this customer buys, or — with no history — what they were just
        // looking at. It runs before every ranked rail and is *not* deduped
        // against them: their own shelf outranks our merchandising, and the
        // rails below dedupe against it instead.
        case 'personal':
          if (feedPending) {
            emit(const SkeletonRail());
            break;
          }
          final personal = feedData?.personal;
          if (personal == null || personal.isEmpty) break;
          shown.addAll(personal.products.map((product) => product.id));
          emit(
            ProductRailView(
              title: personal.title,
              subtitle: personal.anyDue ? l.homeReorderDue : null,
              products: personal.products,
              zone: 'home_${personal.kind}',
              onAdd: add,
              onSeeAll: personal.kind == 'buyagain'
                  ? () => context.push('/buy-again')
                  : null,
            ),
          );

        case 'shipping_nudge':
          if (freeShipping == null) break;
          emit(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              child: FreeShippingBar(freeShipping: freeShipping),
            ),
          );

        case 'rail':
          final rail = payload.rail(slot.key);
          if (rail == null) break;
          final products = claim(rail.products);
          if (products == null) break;
          emit(
            ProductRailView(
              title: rail.title,
              products: products,
              zone: rail.key,
              onAdd: add,
              onSeeAll: () => context.push(
                Uri(
                  path: '/listing',
                  queryParameters: {'rail': rail.key, 'title': rail.title},
                ).toString(),
              ),
            ),
          );

        case 'banner':
          final index = slot.index ?? bannerCursor;
          bannerCursor = index + 1;
          if (index < 0 || index >= bannerPool.length) break;
          emit(CampaignBanner(campaign: bannerPool[index]));

        case 'feed_rail':
          if (feedPending) {
            emit(const SkeletonRail());
            break;
          }
          final rail = switch (slot.key) {
            'foryou' => feedData?.forYou,
            'incity' => feedData?.inCity,
            _ => null,
          };
          if (rail == null) break;
          final products = claim(rail.products);
          if (products == null) break;
          emit(
            ProductRailView(
              title: rail.title,
              products: products,
              zone: 'home_${slot.key}',
              onAdd: add,
            ),
          );

        case 'clearance_band':
          final rail = payload.rail('clearance');
          if (rail == null) break;
          final products = claim(rail.products);
          if (products == null) break;
          emit(ClearanceBand(title: rail.title, products: products, onAdd: add));

        // Saved items, sale first — the reason someone saved a product is
        // usually the price, so a drop is the news.
        case 'wishlist_rail':
          final sorted = [
            ...wishlist.where((product) => product.onSale),
            ...wishlist.where((product) => !product.onSale),
          ];
          final products = claim(sorted);
          if (products == null) break;
          emit(
            ProductRailView(
              title: l.homeWishlistRail,
              products: products,
              zone: 'home_wishlist',
              onAdd: add,
              onSeeAll: () => context.push('/wishlist'),
            ),
          );

        case 'brands':
          if (payload.brands.isEmpty) break;
          emit(BrandStrip(brands: payload.brands));

        case 'trust':
          emit(const TrustStrip(), bottom: 12);

        // Unknown slot: the server is ahead of this build. Skip it silently —
        // a gap is invisible, a crash is not.
        default:
          break;
      }
    }

    return slivers;
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
              height: HeroMetrics.height(context, MediaQuery.sizeOf(context).width),
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
