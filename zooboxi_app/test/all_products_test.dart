import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/catalog/presentation/listing_screen.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/all_products_head.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/facet_sheet.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// «كل المنتجات» (owner's pick A + C's auto-pet, 2026-09-24): the whole store
/// headed by the pet tabs and the shelf row, opened on the family's only
/// kind of pet; the sheet with the food facets locked until «الطعام»; the
/// way in from the categories tab. Store numbers of the day. A design
/// golden: refresh with `flutter test test/all_products_test.dart --update-goldens`, then look.

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

ProductCard _p(int id, String name, double price) => ProductCard(
      id: id,
      name: name,
      itemCode: 'P$id',
      price: price,
      regularPrice: price,
      onSale: false,
      cutout: 'https://x/cut-$id.png',
    );

Map<String, dynamic> _v(String key, String label, int count, {String? icon, String? short, bool selected = false}) => {
      'key': key,
      'label': label,
      'count': count,
      'icon': ?icon,
      'short': ?short,
      'selected': selected,
    };

ListingFacets _facets(ListingQuery q) {
  final cat = q.isSelected('species', 'cat');
  final food = q.isSelected('dept', 'food');
  return ListingFacets.fromJson({
    'species': null,
    'speak_as': cat ? 'cat' : null,
    'base_total': 3752,
    'groups': [
      {
        'key': 'species',
        'label': 'الأليف',
        'icon': 'all',
        'values': [
          _v('cat', 'قطط', food ? 526 : 2026, icon: 'cat_adult', selected: cat),
          _v('dog', 'كلاب', food ? 169 : 1093, icon: 'dog_adult'),
          _v('bird', 'طيور', food ? 216 : 353, icon: 'bird'),
          _v('small', 'حيوانات صغيرة', food ? 26 : 186, icon: 'small', short: 'صغيرة'),
        ],
      },
      {
        'key': 'dept',
        'label': 'القسم',
        'icon': 'food',
        'values': [
          _v('food', 'الطعام', cat ? 526 : 937, icon: 'food', short: 'طعام', selected: food),
          _v('toy', 'الألعاب والخدّاشات', cat ? 311 : 518, icon: 'toy', short: 'ألعاب'),
          _v('treat', 'المكافآت', cat ? 246 : 438, icon: 'treat', short: 'مكافآت'),
          _v('litter', 'الرمل والنشارة', cat ? 219 : 254, icon: 'litter', short: 'رمل'),
          _v('health', 'الصحة والفيتامينات', cat ? 214 : 435, icon: 'health', short: 'صحة'),
          _v('bed', 'البيوت والأسرّة', cat ? 194 : 257, icon: 'bed', short: 'بيوت وأسرّة'),
          _v('collar', 'الأطواق والمشدّات', cat ? 187 : 473, icon: 'collar', short: 'أطواق'),
          _v('groom', 'العناية والنظافة', cat ? 168 : 357, icon: 'groom', short: 'عناية'),
          _v('bowl', 'أوعية الأكل والشرب', cat ? 128 : 185, icon: 'bowl', short: 'أوعية'),
          _v('carrier', 'حقائب التنقل', cat ? 79 : 82, icon: 'carrier', short: 'تنقّل'),
          _v('bundle', 'البكجات', 38, icon: 'bundle', short: 'بكجات'),
        ],
      },
      if (food)
        {
          'key': 'life',
          'label': 'العمر',
          'icon': 'kitten',
          'values': [
            _v('young', 'قطط صغيرة', 61, icon: 'kitten'),
            _v('adult', 'بالغة', 457, icon: 'cat_adult'),
            _v('senior', 'كبيرة السن', 5, icon: 'cat_senior'),
          ],
        },
      {
        'key': 'brand',
        'label': 'العلامة',
        'icon': 'brand',
        'values': [_v('zolux', 'Zolux', 327), _v('kit-cat', 'Kit Cat', 183), _v('inaba', 'INABA', 111)],
      },
      {
        'key': 'offer',
        'label': 'العروض',
        'icon': 'sale',
        'values': [_v('bundle', 'ضمن بكج', 38, icon: 'bundle'), _v('new', 'وصل حديثًا', 1, icon: 'star')],
      },
    ],
    'promoted': [
      {'group': 'brand', 'value': 'zolux', 'label': 'Zolux', 'count': 327},
      {'group': 'brand', 'value': 'kit-cat', 'label': 'Kit Cat', 'count': 183},
      {'group': 'brand', 'value': 'inaba', 'label': 'INABA', 'count': 111},
    ],
    'locked': food
        ? null
        : {
            'groups': ['form', 'texture', 'life', 'flavor'],
            'label': 'العمر · النكهة · القوام',
            'hint': 'تظهر عند اختيار الطعام',
            'unlock': {'group': 'dept', 'value': 'food', 'count': 526},
          },
  });
}

class _FakeCatalog implements CatalogRepository {
  final queries = <ListingQuery>[];

  @override
  Future<ListingResult> products(ListingQuery query, int page) async {
    queries.add(query);
    final cat = query.isSelected('species', 'cat');
    return ListingResult(
      products: [
        _p(14101, 'ناتشرال كود أظرف تونا للقطط الصغيرة 70غ', 6.42),
        _p(14519, 'سينيور غاتو الوردي النقي رمل مهد للقطط 10 لتر', 48),
        _p(11324, 'كوكو لعبة قطط كيب أون سمايلينج 3.5سم أصفر', 4.26),
        _p(16756, 'زولكس سويتيز مكافآت دجاج وسلطعون للقطط 14غ', 2.45),
      ],
      total: cat ? 2026 : 3752,
      pages: 1,
      page: page,
      facets: _facets(query),
      sortOptions: const [
        SortOption(key: 'recommended', label: 'الأنسب لك', icon: 'spark'),
        SortOption(key: 'popularity', label: 'الأكثر مبيعًا', icon: 'star'),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<LocalStore> _storeWith(List<Map<String, String>> pets) async {
  SharedPreferences.setMockInitialValues({'pets.household.v1': jsonEncode(pets)});
  return LocalStore(await SharedPreferences.getInstance());
}

Widget _app({required LocalStore store, required _FakeCatalog catalog, required Widget home, Brightness brightness = Brightness.light}) {
  final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      eventsBufferProvider.overrideWithValue(_SilentEvents()),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      catalogRepositoryProvider.overrideWithValue(catalog),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: theme,
      home: home,
    ),
  );
}

Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = (element.widget as Image).image;
      if (image is AssetImage || image.runtimeType.toString().contains('Asset')) {
        await precacheImage(image, element);
      }
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
}

/// The grid's entrance animations leave timers; unmount and let them run out.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('a one-kind family opens on its pet, best sellers first', (tester) async {
    final catalog = _FakeCatalog();
    final store = await _storeWith([
      {'species': 'cat', 'name': 'لولو'},
      {'species': 'cat', 'name': 'مشمش'},
    ]);
    await tester.pumpWidget(_app(store: store, catalog: catalog, home: const ListingScreen(query: ListingQuery(), allProducts: true)));
    await tester.pump(const Duration(seconds: 1));
    final first = catalog.queries.first;
    expect(first.filters['species'], {'cat'});
    expect(first.orderBy, 'popularity');
    expect(first.category, isNull);
    await _settle(tester);
  });

  testWidgets('a mixed family opens on everyone', (tester) async {
    final catalog = _FakeCatalog();
    final store = await _storeWith([
      {'species': 'cat', 'name': 'لولو'},
      {'species': 'dog', 'name': 'ماكس'},
    ]);
    await tester.pumpWidget(_app(store: store, catalog: catalog, home: const ListingScreen(query: ListingQuery(), allProducts: true)));
    await tester.pump(const Duration(seconds: 1));
    expect(catalog.queries.first.filters.containsKey('species'), isFalse);
    await _settle(tester);
  });

  testWidgets('a shelf chip picks that shelf alone and a second tap lets it go', (tester) async {
    final catalog = _FakeCatalog();
    final store = await _storeWith([
      {'species': 'cat', 'name': 'لولو'},
    ]);
    await tester.pumpWidget(_app(store: store, catalog: catalog, home: const ListingScreen(query: ListingQuery(), allProducts: true)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('ألعاب'));
    await tester.pump(const Duration(seconds: 1));
    expect(catalog.queries.last.filters['dept'], {'toy'});
    expect(catalog.queries.last.filters['species'], {'cat'}, reason: 'the pet stays');
    await tester.tap(find.text('ألعاب'));
    await tester.pump(const Duration(seconds: 1));
    expect(catalog.queries.last.filters.containsKey('dept'), isFalse);
    // The applied row does not repeat what the head already shows.
    expect(find.text('مُطبّق:'), findsNothing);
    await _settle(tester);
  });

  testWidgets('the locked tile picks food in the sheet', (tester) async {
    final catalog = _FakeCatalog();
    final store = await _storeWith(const []);
    const query = ListingQuery(filters: {'species': {'cat'}});
    await tester.pumpWidget(_app(
      store: store,
      catalog: catalog,
      home: Scaffold(body: FacetSheet(query: query, facets: _facets(query), total: 2026)),
    ));
    await tester.pump();
    expect(find.text('العمر'), findsNothing);
    await tester.tap(find.text('العمر · النكهة · القوام'));
    await tester.pump(const Duration(seconds: 1));
    expect(catalog.queries.last.filters['dept'], {'food'});
    expect(find.text('العمر'), findsOneWidget);
    await _settle(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('all products ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3 + 48, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await _storeWith([
        {'species': 'cat', 'name': 'لولو'},
      ]);
      final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
      Widget phone(Widget child) => SizedBox(
            width: 393,
            height: 900,
            child: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.only(top: 44), disableAnimations: true, size: Size(393, 900)),
              child: child,
            ),
          );
      const catQuery = ListingQuery(filters: {'species': {'cat'}});
      await tester.pumpWidget(_app(
        store: store,
        catalog: _FakeCatalog(),
        brightness: brightness,
        home: ColoredBox(
          color: brightness == Brightness.dark ? const Color(0xFF0A0C0B) : const Color(0xFFE9ECE8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              phone(const ListingScreen(query: ListingQuery(), allProducts: true)),
              const SizedBox(width: 24),
              phone(Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    clipBehavior: Clip.antiAlias,
                    child: FacetSheet(query: catQuery, facets: _facets(catQuery), total: 2026, initialGroup: 'dept'),
                  ),
                ),
              )),
              const SizedBox(width: 24),
              phone(Scaffold(
                appBar: AppBar(title: const Text('الأقسام')),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(alignment: Alignment.topCenter, child: AllProductsCard(onOpen: () {})),
                ),
              )),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await _decode(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/all_products_${brightness.name}.png'));
    });
  }
}
