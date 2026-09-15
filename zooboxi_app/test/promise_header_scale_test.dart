import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/promise_header.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/stub_cart.dart';

/// The «الوعد» header is the same height on every phone.
///
/// Android phones commonly run a larger system font, and the header — a
/// composition with fixed geometry — grew with it, so it stood taller there
/// than on the iPhone it was drawn for. Its type is now pinned: at the app's
/// largest permitted scale it measures exactly what it measures at 1.0.

class _At extends LocationController {
  @override
  LocationState build() => LocationState(
        location: ZbLocation(
          lat: 24.74,
          lng: 46.66,
          city: 'الرياض',
          district: 'حي الملك فهد',
          label: 'المنزل',
          deliveryType: 'express',
          warehouseCode: 'RUH010',
          setAt: DateTime(2026, 9, 10, 18),
        ),
      );
}

const _scope = CatalogScope(
  tier: 'express',
  note: 'خلال ساعتين',
  shelf: 'express',
  label: 'خلال ساعتين',
  expressBranch: 'فرع الملك فهد',
  expressHours: ExpressHours(openMinutes: 540, closeMinutes: 1380),
  expressAvailable: true,
);

Widget _page(LocalStore store, double scale) {
  final now = DateTime(2026, 9, 10, 14, 12);
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      locationProvider.overrideWith(_At.new),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light(const Locale('ar')),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          padding: const EdgeInsets.only(top: 44),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: PromiseHeader(scope: _scope, now: now)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  late LocalStore store;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
  });

  Future<Size> measure(WidgetTester tester, double scale) async {
    await withClock(Clock.fixed(DateTime(2026, 9, 10, 14, 12)), () async {
      await tester.pumpWidget(_page(store, scale));
      await tester.pumpAndSettle();
    });
    expect(tester.takeException(), isNull);
    return tester.getSize(find.byType(PromiseHeader));
  }

  testWidgets('the header measures the same at the largest system font', (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await measure(tester, 1.0);
    final large = await measure(tester, 1.3);
    expect(large.height, base.height);
    expect(large.width, base.width);
  });

  testWidgets('and the same on a narrow Android width', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await measure(tester, 1.0);
    final large = await measure(tester, 1.3);
    expect(large.height, base.height);
  });
}
