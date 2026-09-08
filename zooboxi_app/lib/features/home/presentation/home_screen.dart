import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/bundle_card.dart';
import '../../../core/widgets/rail.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../cart/presentation/widgets/free_shipping_bar.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/motion/motion.dart';
import '../../../core/shelf/shelf_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../location/presentation/location_drift_sheet.dart';
import '../../../core/notifications/local_notify.dart';
import '../../loyalty/data/loyalty_models.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/address_nav_bar.dart';
import 'widgets/animal_nav.dart';
import 'widgets/brand_strip.dart';
import 'widgets/campaign_banner.dart';
import 'widgets/clearance_band.dart';
import 'widgets/family_card.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/home_header.dart';
import 'widgets/missions_strip.dart';
import 'widgets/trust_strip.dart';

/// A `/home` emission that is genuinely a new answer, or null.
///
/// Riverpod re-emits the PREVIOUS payload with the loading flag raised while a
/// dependency-driven refetch is in flight. That value is not an answer — it is
/// the last answer, still on screen. Reading it as one is how the app came to
/// re-adopt the shelf a customer had just tapped away from, and hold it there
/// for the whole round trip: the sign stayed lit on the shop they had left and
/// only crossed when the response landed.
///
/// `isLoading` is the one flag that separates the two; the value itself, and
/// even its runtime type, look identical.
@visibleForTesting
HomePayload? settledPayload(AsyncValue<HomePayload> emission) {
  if (emission.isLoading || emission.hasError) return null;
  return emission.value;
}

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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// The drift offer runs on launch and on every return from the background,
  /// but not more often than this — a customer flipping between apps at a
  /// café is not moving house.
  static const Duration _driftCooldown = Duration(minutes: 20);
  static DateTime? _lastDriftCheck;
  bool _driftSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferDrift());
  }

  @override
  void dispose() {
    _shutterClock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Adopts the store's own answer to «which shop am I standing in».
  ///
  /// The tab is a request; this is the reply. Outside the branch's hours an
  /// إكسبريس request is served as زوبكسي — catalogue, basket and promise
  /// alike — and until the app listened to this it kept the ember chrome and
  /// the two-hour clock over a shop that had quietly become the full store.
  void _adoptServedShelf(HomePayload payload) {
    final served = Shelf.fromWire(payload.scope?.shelf);
    ref.read(effectiveShelfProvider.notifier).report(served);
    _armShutterClock(payload);
    _warmOtherShelf(served, payload);
  }

  /// Re-reads the storefront the moment the branch opens or shuts.
  ///
  /// إكسبريس is a place *and* a time. Without this, someone shopping at 22:55
  /// keeps a two-hour promise for the rest of the evening: the answer only
  /// ever refreshed when a new payload happened to be fetched.
  void _armShutterClock(HomePayload payload) {
    _shutterClock?.cancel();
    final hours = payload.scope?.expressHours;
    if (hours == null || hours.closedToday) return;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    DateTime? next;
    for (final minutes in [hours.openMinutes, hours.closeMinutes]) {
      final mark = midnight.add(Duration(minutes: minutes));
      if (!mark.isAfter(now)) continue;
      if (next == null || mark.isBefore(next)) next = mark;
    }
    if (next == null) return;

    // A few seconds past the mark, so the server has certainly crossed it.
    final wait = next.difference(now) + const Duration(seconds: 10);
    // Nothing further out than one evening: a timer held for half a day is a
    // wake-up the customer never asked for.
    if (wait > const Duration(hours: 8)) return;
    _shutterClock = Timer(wait, () {
      if (mounted) ref.invalidate(homeProvider);
    });
  }

  /// Warms the other storefront so crossing the tabs paints instead of
  /// shimmering — the whole of «لمن أغيّر من عادي لإكسبريس المحتوى يتأخر».
  ///
  /// Once per run, two seconds after this storefront has landed, and only for
  /// a shelf the customer can actually reach.
  void _warmOtherShelf(Shelf? served, HomePayload payload) {
    if (_warmedOtherShelf || served == null) return;
    _warmedOtherShelf = true;
    final other = served == Shelf.express ? Shelf.all : Shelf.express;
    if (other == Shelf.express && payload.scope?.expressAvailable != true) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      unawaited(ref.read(catalogRepositoryProvider).prefetchHome(other));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeOfferDrift();
  }

  Future<void> _maybeOfferDrift() async {
    if (_driftSheetOpen) return;
    final last = _lastDriftCheck;
    if (last != null && DateTime.now().difference(last) < _driftCooldown) return;
    _lastDriftCheck = DateTime.now();

    final drift = await ref.read(locationProvider.notifier).detectDrift();
    if (drift == null || !mounted) return;
    _driftSheetOpen = true;
    try {
      await showLocationDriftSheet(context, drift);
    } finally {
      _driftSheetOpen = false;
    }
  }

  /// The other storefront is warmed once per run, a beat after this one has
  /// settled — never on the frame the customer is waiting for.
  bool _warmedOtherShelf = false;

  /// Fires when the express branch's shutter next moves.
  Timer? _shutterClock;

  /// True once the canvas' own address row has scrolled out of reach — the
  /// compact address bar slides in and the status-bar clock flips back dark.
  bool _navVisible = false;

  /// Where the canvas header (address + search) is judged gone. An estimate
  /// is fine: the swap happens mid-scroll, never at rest.
  static const double _navThreshold = 130;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final visible = notification.metrics.pixels > _navThreshold;
    if (visible != _navVisible) setState(() => _navVisible = visible);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // The program's dated reminders ride as local notifications — no push
    // server. Re-synced whenever the summary lands, so a «خلص» tap or a new
    // subscription moves the phone's reminders with it.
    ref.listen<AsyncValue<LoyaltySummary?>>(loyaltySummaryProvider, (_, next) {
      final summary = next.value;
      if (summary != null) unawaited(LocalNotify.sync(summary.nudges));
    });

    // The store's own word on which shelf it served. Taken from the LIVE
    // payload only — a snapshot read off disk is yesterday's answer, and
    // re-reporting it would pin the app to a shop that has since closed.
    //
    // `isLoading` is the whole guard. A dependency-driven refetch re-emits the
    // PREVIOUS payload with the loading flag raised, so without this the tab
    // tap would immediately re-adopt the shelf being left and hold it there
    // for the entire round trip: the sign would stay lit on the old shop,
    // sparkles flying over the one just tapped, and snap across only when the
    // response landed. Which is precisely the stall this phase exists to end.
    ref.listen<AsyncValue<HomePayload>>(homeProvider, (_, next) {
      final payload = settledPayload(next);
      if (payload != null) _adoptServedShelf(payload);
    });
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

    final statusTop = MediaQuery.paddingOf(context).top;

    final shelf = ref.watch(shelfProvider);

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
                child: HeroCarousel(
                  slides: payload.hero,
                  campaigns: payload.campaigns,
                  scope: payload.scope,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ] else
              SliverToBoxAdapter(child: HomeHeader(scope: payload?.scope)),
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
            // The tab bar floats over the feed, so the last rail has to clear
            // it. Scaffold folds the bar's height into the bottom padding —
            // reading it here means the gap is right on every device and stays
            // right if the bar ever changes size.
            SliverToBoxAdapter(
              child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );

    // The canvas runs behind the status bar, so the clock goes light while it
    // is there; the moment the address bar takes over, its surface backs the
    // status bar and the clock flips with it.
    final statusStyle = (canvas && !_navVisible) || context.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    // Crossing the tabs replays the whole page from the other side — a
    // storefront enters, it doesn't refresh. Directional: إكسبريس lives at
    // the start edge, زوبكسي at the end, in both reading directions.
    final storefront = AnimatedSwitcher(
      duration: context.motion(const Duration(milliseconds: 380)),
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.emphasized.flipped,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey(shelf);
        final fromStart = (child.key == const ValueKey(Shelf.express)) == entering;
        final dx = (fromStart ? -0.12 : 0.12) * (context.isRtl ? -1 : 1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(shelf), child: scroll),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusStyle,
      child: Scaffold(
        body: canvas
            ? Stack(
                children: [
                  storefront,
                  // Pinned over the feed: the address that scrolled away with
                  // the canvas, back within thumb's reach.
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    child: AddressNavBar(visible: _navVisible, scope: payload.scope),
                  ),
                ],
              )
            : SafeArea(bottom: false, child: storefront),
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

    // The loyalty layer is *additive* to the storefront: a guest resolves to
    // null without a call, and a failed or slow read is indistinguishable from
    // "no program" — the slot simply doesn't draw. Home must never wait on it.
    final loyalty = ref.watch(loyaltySummaryProvider).value;
    final loyaltyPending =
        ref.watch(isAuthenticatedProvider) && loyalty == null;

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

        // «عائلة زوبوكسي» — the pet, what it needs next, and where its owner
        // stands. Hidden while a member's summary is still in flight rather
        // than flashing the guest invitation at someone who has an account.
        case 'family':
          if (loyaltyPending) break;
          emit(
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
              child: FamilyCard(summary: loyalty, feed: feedData),
            ),
          );

        case 'missions':
          if (!MissionsStrip.hasContent(loyalty)) break;
          emit(
            MissionsStrip(
              missions: loyalty!.missions.items,
              holdout: loyalty.member.holdout,
              awaitingDelivery: loyalty.hasPendingAppOrder,
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
            'bundles' => feedData?.bundles,
            _ => null,
          };
          if (rail == null) break;
          final products = claim(rail.products);
          if (products == null) break;
          // Bundles get their own bigger card — the collage artwork is the
          // pitch — and a home of their own behind «عرض الكل».
          if (slot.key == 'bundles') {
            emit(
              BundleRailView(
                title: rail.title,
                products: products,
                zone: 'home_bundles',
                onAdd: add,
                onSeeAll: () => context.push('/bundles'),
              ),
            );
            break;
          }
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
