import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/shelf/shelf_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/shelf_tabs.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

class _FixedLocation extends LocationController {
  _FixedLocation(this._type);

  final String? _type;

  @override
  LocationState build() => LocationState(
        location: ZbLocation(
          lat: 24.7,
          lng: 46.6,
          city: 'الرياض',
          deliveryType: _type,
          warehouseCode: _type == 'express' ? 'RUH010' : 'RUH002',
        ),
      );
}

Future<ProviderContainer> _container({String? deliveryType, String? savedShelf}) async {
  SharedPreferences.setMockInitialValues({'shelf.selected': ?savedShelf});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWithValue(LocalStore(prefs)),
    locationProvider.overrideWith(() => _FixedLocation(deliveryType)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShelfController', () {
    test('inside an express zone the fast store opens by default', () async {
      final c = await _container(deliveryType: 'express');
      expect(c.read(shelfProvider), Shelf.express);
      expect(c.read(expressAvailableProvider), isTrue);
    });

    test('a remembered preference for the full store survives', () async {
      final c = await _container(deliveryType: 'express', savedShelf: 'all');
      expect(c.read(shelfProvider), Shelf.all);
    });

    test('outside an express zone only the full store exists, whatever was saved', () async {
      final c = await _container(deliveryType: 'same_day', savedShelf: 'express');
      expect(c.read(shelfProvider), Shelf.all);
      expect(c.read(expressAvailableProvider), isFalse);
    });

    test('selecting switches, persists, and refreshes the catalogue', () async {
      final c = await _container(deliveryType: 'express');
      final before = c.read(catalogRevisionProvider);

      c.read(shelfProvider.notifier).select(Shelf.all);
      expect(c.read(shelfProvider), Shelf.all);
      expect(c.read(localStoreProvider).shelf, 'all');
      expect(c.read(catalogRevisionProvider), before + 1);
    });

    test('the dimmed express tab cannot be selected from outside the zone', () async {
      final c = await _container(deliveryType: 'same_day');
      final before = c.read(catalogRevisionProvider);
      c.read(shelfProvider.notifier).select(Shelf.express);
      expect(c.read(shelfProvider), Shelf.all);
      expect(c.read(catalogRevisionProvider), before);
    });
  });

  group('ShelfTabs', () {
    Future<void> pump(WidgetTester tester, ProviderContainer container) => tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('ar'),
              theme: AppTheme.light(const Locale('ar')),
              localizationsDelegates: const [
                L.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ar')],
              home: const Scaffold(
                body: Padding(padding: EdgeInsets.all(16), child: ShelfTabs()),
              ),
            ),
          ),
        );

    testWidgets('both storefronts show, and a tap switches to the full store', (tester) async {
      final c = await _container(deliveryType: 'express');
      await pump(tester, c);

      expect(find.text('إكسبريس'), findsOneWidget);
      expect(find.text('زوبكسي'), findsOneWidget);
      expect(c.read(shelfProvider), Shelf.express);

      await tester.tap(find.text('زوبكسي'));
      await tester.pumpAndSettle();
      expect(c.read(shelfProvider), Shelf.all);
    });

    testWidgets('outside the zone the express tab explains itself instead of switching',
        (tester) async {
      final c = await _container(deliveryType: 'same_day');
      await pump(tester, c);

      await tester.tap(find.text('إكسبريس'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.read(shelfProvider), Shelf.all);
      expect(find.textContaining('غير متاح'), findsOneWidget);
      // Let the toast's own dismissal timer fire before the tree goes away.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
