import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zooboxi_app/app/shell/main_shell.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/home_header.dart';
import 'package:zooboxi_app/features/search/presentation/search_screen.dart';
import 'package:zooboxi_app/features/search/presentation/search_transition.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// Search left the header and became a button that *turns into* the field.
/// Three things must hold for that to be true rather than merely coded: the
/// header no longer carries a field, the flight plays the same way home as it
/// does out, and the canvas — which builds the header three times over — does
/// not put three copies of one hero on the same screen.

const String _hint = 'ابحث عن منتج أو ماركة أو باركود';

class _InRiyadh extends LocationController {
  @override
  LocationState build() => const LocationState(
        location: ZbLocation(
          lat: 24.75,
          lng: 46.66,
          city: 'الرياض',
          district: 'الملك فهد',
          deliveryType: 'express',
        ),
      );
}

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

late LocalStore _store;

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  HomePayload? payload,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        locationProvider.overrideWith(_InRiyadh.new),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        cartFreeShippingNudgeProvider.overrideWithValue(null),
        if (payload != null) ...[
          homeProvider.overrideWithValue(AsyncValue.data(payload)),
          homeFeedProvider.overrideWithValue(const AsyncValue.data(HomeFeed.empty)),
        ],
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => home),
            GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          ],
        ),
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How present the hint is inside the flying object. The Text exists for the
/// whole flight — it is the *opacity* that says which end the object is at,
/// which is exactly what a reversed animation gets backwards.
double _hintOpacity(WidgetTester tester) {
  final finder = find.ancestor(of: find.text(_hint), matching: find.byType(Opacity));
  if (finder.evaluate().isEmpty) return 0;
  return tester.widgetList<Opacity>(finder).first.opacity;
}

/// The four-tab shell, as the app builds it, with two of the tabs carrying a
/// search button.
Widget _shellApp() => ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        locationProvider.overrideWith(_InRiyadh.new),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        cartFreeShippingNudgeProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/search',
              parentNavigatorKey: _rootKey,
              builder: (_, _) => const SearchScreen(),
            ),
            StatefulShellRoute.indexedStack(
              parentNavigatorKey: _rootKey,
              builder: (_, _, shell) => MainShell(shell: shell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/home',
                      builder: (_, _) => const Scaffold(
                        body: Center(child: SearchHeroButton(branch: 0)),
                      ),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/categories',
                      builder: (_, _) => const Scaffold(
                        body: Center(child: SearchHeroButton(branch: 1)),
                      ),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: '/cart', builder: (_, _) => const Scaffold()),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: '/account', builder: (_, _) => const Scaffold()),
                  ],
                ),
              ],
            ),
          ],
          navigatorKey: _rootKey,
        ),
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
      ),
    );

final _rootKey = GlobalKey<NavigatorState>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('the header spends no width on an empty input', (tester) async {
    await _pump(tester, home: const Scaffold(body: HomeHeader()));

    // The hint belongs to the screen the button opens, not to home.
    expect(find.text(_hint), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SearchHeroButton), findsOneWidget);
  });

  testWidgets('the field grows out of the button, and collapses back into it',
      (tester) async {
    await _pump(
      tester,
      home: const Scaffold(body: Center(child: SearchHeroButton(branch: 0))),
    );

    await tester.tap(find.byType(SearchHeroButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Early in the flight the object is still mostly a button: the hint has
    // not arrived yet.
    expect(_hintOpacity(tester), lessThan(0.2));

    await tester.pump(const Duration(milliseconds: 200));
    // Late in the flight it reads as the field it is becoming.
    expect(_hintOpacity(tester), greaterThan(0.5));

    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Going back plays the same shape in reverse: at the *start* of the pop
    // the object is still the field, hint and all. An animation driven
    // backwards would blank it on the first frame instead.
    GoRouter.of(tester.element(find.byType(SearchScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      _hintOpacity(tester),
      greaterThan(0.5),
      reason: 'the field collapses, it does not blink out on the first frame',
    );

    await tester.pumpAndSettle();
    expect(find.byType(SearchHeroButton), findsOneWidget);
    expect(find.text(_hint), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hero canvas builds the header three times and still flies once',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The real canvas: a hero slide, which is what makes HomeScreen build the
    // carousel — the real header, plus an invisible twin inside every slide.
    await _pump(
      tester,
      home: const HomeScreen(),
      payload: const HomePayload(
        hero: [HeroSlide(title: 'بانر المتجر')],
        layout: [HomeLayoutSlot('hero')],
      ),
    );

    expect(find.byType(SearchHeroButton), findsWidgets);
    // `.last` is the real header: the ghosts inside the PageView come first in
    // the canvas Stack and are IgnorePointer, so tapping one only "works"
    // because it sits exactly on top of the real button.
    await tester.tap(find.byType(SearchHeroButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Two heroes sharing a tag in one route is an assertion, not a glitch.
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('a tab the customer visited earlier does not steal the flight',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shellApp());
    await tester.pumpAndSettle();

    // Visit الأقسام, then come back. Both tabs are alive from here on, and
    // both carry a search button.
    await tester.tap(find.text('الأقسام'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SearchHeroButton), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Ungated, this is where two heroes share one tag and the screen turns red.
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('leaving search by the menu does not fly the pill to a hidden tab',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shellApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SearchHeroButton));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    // The main menu travels with the customer, so leaving search this way is
    // a pop — and the home button it would fly back to is about to be on a
    // tab nobody is looking at.
    GoRouter.of(tester.element(find.byType(SearchScreen))).go('/categories');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Nothing is mid-flight toward a hidden header: the pill is not on screen.
    expect(_hintOpacity(tester), 0);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(SearchHeroButton), findsOneWidget);
  });
}
