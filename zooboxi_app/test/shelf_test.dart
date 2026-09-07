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
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
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
    Future<void> pumpWith(
      WidgetTester tester,
      ProviderContainer container,
      ExpressHours? hours,
    ) =>
        tester.pumpWidget(
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
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShelfTabs(hours: hours),
                ),
              ),
            ),
          ),
        );

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

    testWidgets('the express sign carries the branch hours, not its speed', (tester) async {
      final c = await _container(deliveryType: 'express');
      await pumpWith(
        tester,
        c,
        const ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
      );

      expect(find.text('9 ص – 11 م'), findsOneWidget);
      expect(find.text('خلال ساعتين'), findsNothing);
      // The زوبكسي line names the day the main warehouse can make — «اليوم»
      // before one o'clock, «غدًا» after it. Which one it is today is the
      // cut-off rule's own business, and tested in delivery_eta_test.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('يصلك '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the server, not the saved address, decides the sign is shut',
        (tester) async {
      // Saved as express at noon, opened at midnight: the app must follow the
      // server's live answer, not the address's memory.
      final c = await _container(deliveryType: 'express');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
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
              body: Padding(
                padding: EdgeInsets.all(16),
                child: ShelfTabs(
                  hours: ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
                  expressAvailable: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('يفتح 9 ص'), findsOneWidget);
      // And the lit sign is زوبكسي, which is the shelf being served.
      expect(c.read(shelfProvider), Shelf.express, reason: 'the preference is kept');
    });

    testWidgets('out of hours the same sign says when it reopens', (tester) async {
      // Outside express hours the server stops offering express at all, so
      // the tab dims — but it still knows the branch and its schedule.
      final c = await _container(deliveryType: 'same_day');
      await pumpWith(
        tester,
        c,
        const ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60),
      );

      expect(find.text('يفتح 9 ص'), findsOneWidget);
    });

    testWidgets('outside the zone the express tab explains itself instead of switching',
        (tester) async {
      final c = await _container(deliveryType: 'same_day');
      await pump(tester, c);

      await tester.tap(find.text('إكسبريس'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.read(shelfProvider), Shelf.all);
      // The dimmed sign already says «غير متاح هنا»; the toast is the longer
      // sentence naming the location.
      expect(find.text('غير متاح هنا'), findsOneWidget);
      expect(find.text('التوصيل السريع غير متاح في موقعك الحالي'), findsOneWidget);
      // Let the toast's own dismissal timer fire before the tree goes away.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
