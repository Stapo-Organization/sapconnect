import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/product_grid_sliver.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_band.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_offers.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/hero_carousel.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// إكسبريس composes itself differently because it is a different errand: it
/// leads with when the order arrives, and it lays the shelf out as a shelf
/// rather than as a magazine of six-card strips. The server decides that — the
/// layout is its call — so these lock the app's half: that it can draw the two
/// slots the express composition is built from, and that the band tells the
/// truth on both sides of closing time.

ProductCard _p(int id) => ProductCard(id: id, name: 'P$id', itemCode: 'C$id', price: 10);

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

const _hours = ExpressHours(openMinutes: 9 * 60, closeMinutes: 24 * 60);

const _expressScope = CatalogScope(
  tier: 'express',
  note: 'كل ما هنا يصلك خلال ساعتين',
  shelf: 'express',
  label: 'توصيل خلال ساعتين',
  expressBranch: 'فرع الملك فهد',
  expressAvailable: true,
  expressHours: _hours,
);

/// A customer standing inside the express zone — otherwise the app resolves
/// to زوبكسي and refuses to paint an express payload over it, which is the
/// Phase 0 guard doing its job.
class _InExpressZone extends LocationController {
  @override
  LocationState build() => const LocationState(
        location: ZbLocation(
          lat: 24.7464,
          lng: 46.6793,
          city: 'الرياض',
          deliveryType: 'express',
          warehouseCode: 'RUH010',
        ),
      );
}

late LocalStore _store;

Widget _host(HomePayload payload, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        cartFreeShippingNudgeProvider.overrideWithValue(null),
        locationProvider.overrideWith(_InExpressZone.new),
        homeProvider.overrideWithValue(AsyncValue.data(payload)),
        homeFeedProvider.overrideWithValue(const AsyncValue.data(HomeFeed.empty)),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );

Widget _band(DateTime at, {CatalogScope scope = _expressScope}) => MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.light(const Locale('ar')),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: ExpressEtaBand(scope: scope, now: at)),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  group('the express storefront is laid out as a shelf', () {
    final payload = HomePayload(
      scope: _expressScope,
      rails: [
        ProductRail(
          key: 'trending',
          title: 'رائج الآن',
          products: [_p(1), _p(2), _p(3), _p(4), _p(5), _p(6)],
        ),
      ],
      layout: const [
        HomeLayoutSlot('eta_band'),
        HomeLayoutSlot('grid', key: 'trending'),
      ],
    );

    testWidgets('it opens with the arrival, not with a carousel',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(payload));
      await tester.pumpAndSettle();

      expect(find.byType(ExpressEtaBand), findsOneWidget);
      expect(find.byType(HeroCarousel), findsNothing);
      // The address stays reachable even with no canvas above it.
      expect(find.text('رائج الآن'), findsOneWidget);
    });

    testWidgets('a rail asked for as a grid is drawn as one', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(payload));
      await tester.pumpAndSettle();

      expect(find.byType(ProductGridSliver), findsOneWidget);
      // Not a strip: the same six products, in columns.
      expect(find.byType(ProductRailView), findsNothing);
    });

    testWidgets('a grid too thin to be a grid steps aside', (tester) async {
      final thin = HomePayload(
        scope: _expressScope,
        rails: [
          ProductRail(key: 'trending', title: 'رائج الآن', products: [_p(1), _p(2)]),
        ],
        layout: const [
          HomeLayoutSlot('eta_band'),
          HomeLayoutSlot('grid', key: 'trending'),
        ],
      );
      await tester.pumpWidget(_host(thin));
      await tester.pumpAndSettle();

      expect(find.byType(ProductGridSliver), findsNothing);
      expect(find.text('رائج الآن'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the band tells the truth on both sides of closing time', () {
    testWidgets('open: the arrival leads, the branch is named under it',
        (tester) async {
      // 09:15 — two and a half hours of lead lands at 11:45.
      await tester.pumpWidget(_band(DateTime(2026, 9, 9, 9, 15)));
      expect(find.textContaining('11:45'), findsOneWidget);
      expect(find.textContaining('فرع الملك فهد'), findsOneWidget);
    });

    testWidgets('shut: the opening leads, and it still promises a time',
        (tester) async {
      // 03:00 — the branch opens at 09:00, so the first delivery is 11:30.
      await tester.pumpWidget(_band(DateTime(2026, 9, 9, 3, 0)));
      // A whole hour is written bare — «يفتح 9 ص», not «9:00».
      expect(find.textContaining('9'), findsWidgets);
      expect(find.textContaining('11:30'), findsOneWidget);
    });

    testWidgets('a branch keeping no schedule is simply open', (tester) async {
      await tester.pumpWidget(
        _band(
          DateTime(2026, 9, 9, 3, 0),
          scope: const CatalogScope(
            tier: 'express',
            note: 'n',
            shelf: 'express',
            expressBranch: 'فرع الملك فهد',
          ),
        ),
      );
      expect(find.textContaining('5:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  /// زوبكسي opens on a full-bleed canvas — the header fused into it, the slide
  /// behind the status bar. The dark store cannot afford that screen; it gets
  /// a strip of cards a thumb's swipe wide, with the next already peeking.
  group('إكسبريس gets offers, not a hero', () {
    const slides = [
      HeroSlide(
        kind: 'auto',
        theme: 'express_clock',
        title: 'يوصلك خلال ساعتين',
        subtitle: 'من فرع الملك فهد',
        ctaLabel: 'اطلب الآن',
      ),
      HeroSlide(
        kind: 'auto',
        theme: 'express_new',
        title: 'وصل حديثاً إلى فرعك',
        ctaLabel: 'شاهد الجديد',
      ),
    ];

    test('a strip with nothing to put in it is no strip', () {
      expect(ExpressOfferSlider.hasContent(const []), isFalse);
      expect(
        ExpressOfferSlider.hasContent(const [HeroSlide(kind: 'auto')]),
        isFalse,
      );
      expect(ExpressOfferSlider.hasContent(slides), isTrue);
    });

    testWidgets('the first card is readable and the next one peeks',
        (tester) async {
      tester.view.physicalSize = const Size(393, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light(const Locale('ar')),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const Scaffold(
            body: Center(child: ExpressOfferSlider(slides: slides)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('يوصلك خلال ساعتين'), findsOneWidget);
      expect(find.text('من فرع الملك فهد'), findsOneWidget);
      expect(find.text('اطلب الآن'), findsOneWidget);
      // The second card is built and on screen, which is the invitation.
      expect(find.text('وصل حديثاً إلى فرعك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the storefront draws it from the payload it already has',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(HomePayload(
        scope: _expressScope,
        hero: slides,
        rails: [
          ProductRail(
            key: 'trending',
            title: 'رائج الآن',
            products: [_p(1), _p(2), _p(3), _p(4)],
          ),
        ],
        layout: const [
          HomeLayoutSlot('eta_band'),
          HomeLayoutSlot('offer_strip'),
          HomeLayoutSlot('grid', key: 'trending'),
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ExpressOfferSlider), findsOneWidget);
      // Still not the store's carousel.
      expect(find.byType(HeroCarousel), findsNothing);
    });
  });
}
