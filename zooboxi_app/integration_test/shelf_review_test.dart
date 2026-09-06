// Visual review harness for the storefront tabs: boots the real home screen
// against the live store on a simulator, with the location pinned, and
// screenshots the three states that matter — express active, the full store,
// and the dimmed express tab outside the zone.
//
//   SCREENSHOT_DIR=… flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/shelf_review_test.dart -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

class _FixedLocation extends LocationController {
  _FixedLocation(this.location);

  final ZbLocation location;

  @override
  LocationState build() => LocationState(location: location);
}

const _kingFahd = ZbLocation(
  lat: 24.7480,
  lng: 46.6650,
  city: 'الرياض',
  district: 'الملك فهد',
  deliveryType: 'express',
  warehouseCode: 'RUH010',
  promiseLabel: 'خلال ساعتين',
);

const _northRiyadh = ZbLocation(
  lat: 24.9100,
  lng: 46.8400,
  city: 'الرياض',
  district: 'النرجس',
  deliveryType: 'same_day',
  warehouseCode: 'RUH002',
  promiseLabel: 'خلال 24 ساعة',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(LocalStore store, ZbLocation location) {
    const locale = Locale('ar');
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/search', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/scan', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/wishlist', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/listing', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/product/:id', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/brands', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/brand/:slug', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/clearance', builder: (_, _) => const Scaffold()),
      ],
    );
    // overrideWith builders are frozen on the first build of a ProviderScope
    // element — pumping the same widget with new overrides silently keeps the
    // old ones. A per-location key forces a fresh element and container.
    return ProviderScope(
      key: ValueKey(location.district),
      overrides: [
        localStoreProvider.overrideWithValue(store),
        locationProvider.overrideWith(() => _FixedLocation(location)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: AppTheme.light(locale),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [locale],
      ),
    );
  }

  Future<void> settle(WidgetTester tester, [int ms = 3000]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('storefront tabs journey', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await store.setLocaleCode('ar');

    // Inside the express zone: both tabs open, express default.
    await tester.pumpWidget(harness(store, _kingFahd));
    await settle(tester, 6000);
    await shot(tester, '01_express_active');

    // Switch to the full store.
    await tester.tap(find.text('زوبكسي').first);
    await settle(tester, 6000);
    await shot(tester, '02_zooboxi_active');

    // Back to express — the remembered preference is express again.
    await tester.tap(find.text('إكسبريس').first);
    await settle(tester, 4000);
    await shot(tester, '03_back_to_express');

    // Outside the zone: the express tab dims; tapping it explains why.
    await tester.pumpWidget(harness(store, _northRiyadh));
    await settle(tester, 6000);
    await shot(tester, '04_express_dimmed');

    await tester.tap(find.text('إكسبريس').first);
    await settle(tester, 700);
    await shot(tester, '05_dimmed_tap_toast');
    await settle(tester, 4000);
  });
}
