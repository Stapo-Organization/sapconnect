import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/animal_nav.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/brand_strip.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/campaign_banner.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/campaign_impression.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_carousel.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/trust_strip.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// Home is server-merchandised: `/home` ships the slot order and the screen
/// renders exactly that. These tests lock the three ways that contract can
/// silently break — an ignored layout, a hidden campaign-only hero, and the
/// same product filling three rails in a row.

ProductCard _p(int id) => ProductCard(id: id, name: 'P$id', itemCode: 'C$id', price: 10);

/// Analytics must never be the reason a test — or a screen — is slow or
/// flaky, so the buffer is stubbed out rather than queued and flushed.
class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

late LocalStore _store;

Widget _host(
  HomePayload payload, {
  HomeFeed feed = HomeFeed.empty,
  Locale locale = const Locale('ar'),
  double textScale = 1,
}) =>
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        // The cart is the shell's business; Home only reads the nudge.
        cartFreeShippingNudgeProvider.overrideWithValue(null),
        homeProvider.overrideWithValue(AsyncValue.data(payload)),
        homeFeedProvider.overrideWithValue(AsyncValue.data(feed)),
      ],
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(locale),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          // Kills the shimmer loop and the rail stagger, so the tree settles.
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );

Future<void> _pumpHome(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(1000, 6000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
    resetCampaignImpressions();
    // Report visibility in the post-frame callback instead of on a timer,
    // which would outlive the test.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('renders slots in the server order and skips unknown types', (tester) async {
    final payload = HomePayload(
      hero: const [HeroSlide(title: 'بانر المتجر')],
      campaigns: const [
        Campaign(campaignId: 'b1', zones: ['app_banner'], headline: 'حملة البانر'),
      ],
      // Present in the payload but absent from the layout: it must not render.
      animalNav: const [AnimalNavItem(id: 1, slug: 'cats', name: 'قطط')],
      rails: [
        ProductRail(key: 'trending', title: 'رائج الآن', products: [_p(1), _p(2), _p(3)]),
        ProductRail(key: 'new', title: 'وصل حديثًا', products: [_p(4), _p(5), _p(6)]),
      ],
      brands: const [BrandSummary(slug: 'zolux', name: 'Zolux')],
      layout: const [
        HomeLayoutSlot('rail', key: 'new'),
        HomeLayoutSlot('wormhole'),
        HomeLayoutSlot('banner', index: 0),
        HomeLayoutSlot('rail', key: 'trending'),
        HomeLayoutSlot('hero'),
        HomeLayoutSlot('trust'),
        HomeLayoutSlot('brands'),
      ],
    );

    await _pumpHome(tester, _host(payload));

    double y(Finder finder) => tester.getTopLeft(finder).dy;
    final order = [
      y(find.text('وصل حديثًا')),
      y(find.byType(CampaignBanner)),
      y(find.text('رائج الآن')),
      y(find.byType(HeroCarousel)),
      y(find.byType(TrustStrip)),
      y(find.byType(BrandStrip)),
    ];
    expect(
      order,
      orderedEquals(<double>[...order]..sort()),
      reason: 'slots must paint top-to-bottom in the order the server sent',
    );

    // The unknown `wormhole` slot drew nothing, and the layout — not the
    // payload — decided what appears: animal_nav has data but no slot.
    expect(find.byType(ProductRailView), findsNWidgets(2));
    expect(find.byType(AnimalNav), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('an absent layout falls back to the documented default order', () {
    expect(const HomePayload().slots, same(HomePayload.defaultLayout));
    expect(
      HomePayload.defaultLayout
          .map((slot) => [slot.type, slot.key ?? slot.index].nonNulls.join(':'))
          .toList(),
      const [
        'hero',
        'animal_nav',
        'personal',
        'shipping_nudge',
        'rail:trending',
        'banner:0',
        'feed_rail:foryou',
        'rail:bestsellers',
        'feed_rail:incity',
        'clearance_band',
        'rail:new',
        'banner:1',
        'wishlist_rail',
        'brands',
        'trust',
      ],
    );
  });

  testWidgets('the personal strip wins, and the rails below dedupe against it',
      (tester) async {
    final feed = HomeFeed(
      personal: PersonalSlot(
        kind: 'buyagain',
        title: 'اطلبها مجددًا',
        products: [_p(1), _p(2)],
        hints: const {1: ReorderHint(lastOrderedDays: 34, due: true)},
      ),
      forYou: FeedRail(title: 'مختارة لك', products: [_p(8), _p(9), _p(10)]),
    );
    final payload = HomePayload(
      // Two of these three are already on this customer's own shelf above.
      rails: [
        ProductRail(key: 'trending', title: 'رائج الآن', products: [_p(1), _p(2), _p(3)]),
      ],
      layout: const [
        HomeLayoutSlot('personal'),
        HomeLayoutSlot('rail', key: 'trending'),
        HomeLayoutSlot('feed_rail', key: 'foryou'),
      ],
    );

    await _pumpHome(tester, _host(payload, feed: feed));

    expect(find.text('اطلبها مجددًا'), findsOneWidget);
    expect(find.text('حان وقت إعادة الطلب'), findsOneWidget, reason: 'a due item nudges');
    expect(find.text('مختارة لك'), findsOneWidget);
    expect(find.text('رائج الآن'), findsNothing, reason: 'one card left is not a rail');
    expect(find.text('P1'), findsOneWidget);
  });

  testWidgets('a campaign-only hero still renders', (tester) async {
    const payload = HomePayload(
      campaigns: [
        Campaign(campaignId: 'c1', zones: ['hero'], headline: 'توصيل خلال ساعتين'),
      ],
      layout: [HomeLayoutSlot('hero')],
    );

    await _pumpHome(tester, _host(payload));

    expect(find.byType(HeroCarousel), findsOneWidget);
    expect(find.text('توصيل خلال ساعتين'), findsOneWidget);
  });

  testWidgets('later rails drop products already shown, and thin rails vanish',
      (tester) async {
    final payload = HomePayload(
      rails: [
        ProductRail(
          key: 'trending',
          title: 'رائج الآن',
          products: [_p(1), _p(2), _p(3), _p(4)],
        ),
        // Shares 3 and 4 with the rail above: keeps 5, 6, 7 — still three, so
        // it survives.
        ProductRail(
          key: 'bestsellers',
          title: 'الأكثر مبيعًا',
          products: [_p(3), _p(4), _p(5), _p(6), _p(7)],
        ),
        // Everything here is already on screen: nothing left to show.
        ProductRail(key: 'new', title: 'وصل حديثًا', products: [_p(1), _p(2), _p(5)]),
      ],
      layout: const [
        HomeLayoutSlot('rail', key: 'trending'),
        HomeLayoutSlot('rail', key: 'bestsellers'),
        HomeLayoutSlot('rail', key: 'new'),
      ],
    );

    await _pumpHome(tester, _host(payload));

    expect(find.text('رائج الآن'), findsOneWidget);
    expect(find.text('الأكثر مبيعًا'), findsOneWidget);
    expect(find.text('وصل حديثًا'), findsNothing);
    expect(find.byType(ProductRailView), findsNWidgets(2));

    for (final id in [1, 2, 3, 4, 5, 6, 7]) {
      expect(find.text('P$id'), findsOneWidget, reason: 'P$id must appear exactly once');
    }
  });

  // Composed campaign art is live text on a fixed-extent card — the exact
  // shape that clips when someone turns their font size up. The hero and the
  // banner grow with the scale and clamp at 1.3×, so neither can overflow.
  for (final scale in const [1.0, 1.3, 2.0]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets(
        'composed campaigns survive scale $scale, ${locale.languageCode}',
        (tester) async {
          // Two placements of the same offer: one in the hero, one between the
          // rails. A single campaign could not do both — the banner pool
          // deliberately excludes whatever the hero already showed.
          Campaign campaign(String id, List<String> zones) => Campaign(
                campaignId: id,
                zones: zones,
                campaignType: 'clearance',
                headline: 'خصومات نهاية الموسم على أطعمة القطط والكلاب',
                subheadline: 'لفترة محدودة على مئات المنتجات',
                cta: 'تسوّق العرض',
                badge: 'عرض محدود',
                couponCode: 'SAVE15',
                discountPct: 15,
                // Three days out: a static chip, so no clock is left ticking.
                endsAt: DateTime.now().add(const Duration(days: 3)),
              );
          final payload = HomePayload(
            hero: const [
              HeroSlide(
                kind: 'auto',
                theme: 'express',
                title: 'وصل خلال ساعتين لطلبك القادم',
                subtitle: 'من أقرب فرع لك',
                ctaLabel: 'تسوّق السريع',
                productImages: ['a', 'b', 'c'],
              ),
            ],
            campaigns: [campaign('hero1', ['hero']), campaign('banner1', ['app_banner'])],
            layout: const [
              HomeLayoutSlot('hero'),
              HomeLayoutSlot('banner', index: 0),
              HomeLayoutSlot('trust'),
            ],
          );

          await _pumpHome(
            tester,
            _host(payload, locale: locale, textScale: scale),
            size: const Size(393, 2000),
          );

          expect(find.byType(HeroCarousel), findsOneWidget);
          // The call to action is the element the slide exists for: if the
          // copy column ever ran out of room, this is what would go first.
          expect(find.text('تسوّق العرض'), findsWidgets);
          expect(find.byType(CampaignBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
