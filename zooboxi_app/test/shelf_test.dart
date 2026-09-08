import 'dart:io';

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
import 'package:zooboxi_app/features/home/presentation/home_screen.dart';
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


/// A stand-in for `/home`: it depends on the shelf being asked for, exactly as
/// the real `homeProvider` depends on `shelfProvider`.
class _AskedShelf extends Notifier<String> {
  @override
  String build() => 'express';
  void ask(String shelf) => state = shelf;
}

final _askedShelf = NotifierProvider<_AskedShelf, String>(_AskedShelf.new);

final _servedHome = FutureProvider<HomePayload>((ref) async {
  final shelf = ref.watch(_askedShelf);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return HomePayload.fromJson({
    'scope': {'shelf': shelf, 'note': 'note'},
    'slots': const [],
  });
});

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

    test('selecting switches, persists, and refreshes only the shelf', () async {
      final c = await _container(deliveryType: 'express');
      final catalogBefore = c.read(catalogRevisionProvider);
      final shelfBefore = c.read(shelfRevisionProvider);

      c.read(shelfProvider.notifier).select(Shelf.all);
      expect(c.read(shelfProvider), Shelf.all);
      expect(c.read(localStoreProvider).shelf, 'all');
      expect(c.read(shelfRevisionProvider), shelfBefore + 1);
      // The city and the language did not move, so the catalogue-wide signal
      // must stay put: bumping it here is what made a tab tap refetch the
      // categories and the brands as well.
      expect(c.read(catalogRevisionProvider), catalogBefore);
    });

    test('the dimmed express tab cannot be selected from outside the zone', () async {
      final c = await _container(deliveryType: 'same_day');
      final before = c.read(shelfRevisionProvider);
      c.read(shelfProvider.notifier).select(Shelf.express);
      expect(c.read(shelfProvider), Shelf.all);
      expect(c.read(shelfRevisionProvider), before);
    });

    test('a tab tap never touches the basket', () async {
      // Switching baskets empties the cart, hands back every claimed gift and
      // drops the restored side's coupons. A glance at the other shop must
      // not cost someone their twelve lines, so `select()` deliberately makes
      // no cart call at all — the cart is moved from the cart screen, or from
      // the sheet an add raises.
      final source = File('lib/core/shelf/shelf_controller.dart').readAsStringSync();
      final body = source.substring(source.indexOf('void select(Shelf shelf)'));
      final end = body.indexOf('\n  }');
      expect(body.substring(0, end), isNot(contains('cartController')));
      expect(body.substring(0, end), isNot(contains('switchBasket')));
    });
  });

  group('the shelf the store actually served', () {
    test('before the server answers, the request stands in for it', () async {
      final c = await _container(deliveryType: 'express');
      expect(c.read(effectiveShelfProvider), isNull);
      expect(c.read(resolvedShelfProvider), Shelf.express);
    });

    test('an after-hours downgrade moves the app without losing the request',
        () async {
      final c = await _container(deliveryType: 'express');
      // The branch has shut: the store answers the إكسبريس tab with زوبكسي.
      c.read(effectiveShelfProvider.notifier).report(Shelf.all);

      // The app behaves as زوبكسي — chrome, cache key, promise…
      expect(c.read(resolvedShelfProvider), Shelf.all);
      // …while the customer's own ask is untouched, so tomorrow morning the
      // app opens on إكسبريس again.
      expect(c.read(shelfProvider), Shelf.express);
      expect(c.read(localStoreProvider).shelf, isNot('all'));
    });

    test('a shelf the server did not name is not guessed at', () async {
      expect(Shelf.fromWire('auto'), isNull);
      expect(Shelf.fromWire(''), isNull);
      expect(Shelf.fromWire(null), isNull);
      expect(Shelf.fromWire('express'), Shelf.express);
      expect(Shelf.fromWire('all'), Shelf.all);
    });

    test('choosing a tab drops the answer that described the old one', () async {
      final c = await _container(deliveryType: 'express');
      c.read(effectiveShelfProvider.notifier).report(Shelf.express);
      c.read(shelfProvider.notifier).select(Shelf.all);
      // Not replaced with a guess — dropped, so the app falls back to what was
      // just asked for until the next payload says what was really served.
      expect(c.read(effectiveShelfProvider), isNull);
      expect(c.read(resolvedShelfProvider), Shelf.all);
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

  group('adopting the shelf the store served', () {
    final payload = HomePayload.fromJson(const {
      'scope': {'shelf': 'express', 'note': 'يصلك خلال ساعتين'},
      'slots': [],
    });

    test('a settled answer is adopted', () {
      expect(settledPayload(AsyncValue.data(payload))?.scope?.shelf, 'express');
    });

    test('a refetch still carrying the old answer is NOT adopted', () async {
      // Driven through a real provider rather than a hand-built value, because
      // the whole bug was a wrong belief about what riverpod emits: the instant
      // a dependency changes it re-emits the PREVIOUS payload with the loading
      // flag raised. Reading that as an answer re-reported the shelf the
      // customer had just tapped away from and pinned the app to it for the
      // entire round trip — the tab looked dead until the response landed.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final emissions = <AsyncValue<HomePayload>>[];
      container.listen<AsyncValue<HomePayload>>(
        _servedHome,
        (_, next) => emissions.add(next),
        fireImmediately: true,
      );

      await container.read(_servedHome.future);
      expect(settledPayload(emissions.last)?.scope?.shelf, 'express');

      emissions.clear();
      container.read(_askedShelf.notifier).ask('all');
      // The rebuild is scheduled, not synchronous; one turn of the event loop
      // is enough and lands well before the 10 ms fetch resolves.
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isNotEmpty,
          reason: 'a dependency change must emit before the fetch resolves');
      final refetching = emissions.first;
      expect(refetching.value, isNotNull,
          reason: 'riverpod really does carry the previous payload through');
      expect(refetching.value!.scope?.shelf, 'express',
          reason: 'and the payload it carries is the OLD one');
      expect(settledPayload(refetching), isNull,
          reason: 'so it must not be adopted as an answer');

      await container.read(_servedHome.future);
      expect(settledPayload(emissions.last)?.scope?.shelf, 'all');
    });

    test('a first load with nothing yet is nothing to adopt', () {
      expect(settledPayload(const AsyncLoading<HomePayload>()), isNull);
    });
  });
}
