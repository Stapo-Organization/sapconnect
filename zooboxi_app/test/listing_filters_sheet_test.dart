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
import 'package:zooboxi_app/features/catalog/presentation/widgets/facet_sheet.dart';
import 'package:zooboxi_app/features/notifications/data/push_repository.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// «اللوحة» (owner's pick, 2026-09-24): the cat-food listing narrowed for
/// لولو (a kitten), the two-pane sheet open on «النكهة», and the empty state
/// that offers the way back — on the store's real numbers for «الطعام
/// الرطب» × «قطط صغيرة». A design golden: refresh with
/// `flutter test test/listing_filters_sheet_test.dart --update-goldens`, then look.

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

Map<String, dynamic> _v(String key, String label, int count, {String? icon, String? sub, String? note, bool selected = false}) => {
      'key': key,
      'label': label,
      'count': count,
      'icon': ?icon,
      'sub': ?sub,
      'note': ?note,
      'selected': selected,
    };

ListingFacets _facets(ListingQuery q) {
  final kitten = q.isSelected('life', 'young');
  final duck = q.isSelected('flavor', 'duck');
  return ListingFacets.fromJson({
    'species': 'cat',
    'base_total': 382,
    'groups': [
      {
        'key': 'texture',
        'label': 'القوام',
        'icon': 'pate',
        'values': [
          _v('pouch', 'أظرف', kitten ? 8 : 93, icon: 'pouch'),
          _v('can', 'معلبات', kitten ? 17 : 156, icon: 'wet'),
          _v('pate', 'باتيه ومهروس', kitten ? 7 : 29, icon: 'pate'),
          _v('gravy', 'في المرق', kitten ? 5 : 96, icon: 'gravy'),
          _v('jelly', 'في الجيلي', kitten ? 3 : 42, icon: 'jelly'),
        ],
      },
      {
        'key': 'life',
        'label': 'العمر',
        'icon': 'kitten',
        'values': [
          _v('young', 'قطط صغيرة', 29, icon: 'kitten', sub: 'حتى 12 شهرًا', selected: kitten),
          _v('adult', 'بالغة', 347, icon: 'cat_adult', sub: 'من سنة إلى 7 سنوات'),
          _v('senior', 'كبيرة السن', 0, icon: 'cat_senior', note: 'غير متوفر في الطعام الرطب'),
        ],
      },
      {
        'key': 'flavor',
        'label': 'النكهة',
        'icon': 'chicken',
        'values': [
          _v('chicken', 'دجاج', kitten ? 15 : 190, icon: 'chicken'),
          _v('tuna', 'تونة', kitten ? 13 : 150, icon: 'tuna'),
          _v('salmon', 'سلمون', kitten ? 2 : 60, icon: 'salmon'),
          _v('fish', 'أسماك أخرى', kitten ? 1 : 40, icon: 'fish_any', sub: 'قد، بولك، سردين…'),
          _v('duck', 'بط', kitten ? 0 : 11, icon: 'duck', note: kitten ? 'غير متوفر مع قطط صغيرة' : null, selected: duck),
          _v('beef', 'لحم بقري', kitten ? 0 : 20, icon: 'beef', note: kitten ? 'غير متوفر مع قطط صغيرة' : null),
        ],
      },
      {
        'key': 'need',
        'label': 'احتياج خاص',
        'icon': 'sterilised',
        'values': [
          _v('grain_free', 'خالٍ من الحبوب', 3, icon: 'grain_free'),
          _v('digest', 'هضم حساس', 2, icon: 'digest'),
          _v('sterilised', 'للمعقّمة', 0, icon: 'sterilised', note: 'غير متوفر مع قطط صغيرة'),
        ],
      },
      {
        'key': 'brand',
        'label': 'العلامة',
        'icon': 'brand',
        'values': [
          _v('kit-cat', 'Kit Cat', 10),
          _v('natural-code', 'Natural Code', 4),
          _v('applaws', 'Applaws', 4),
        ],
      },
      {
        'key': 'pack',
        'label': 'العبوة',
        'icon': 'carton',
        'values': [_v('carton', 'متوفر بالكرتون', 21, icon: 'carton', sub: 'اختر الحبة أو الكرتون في صفحة المنتج')],
      },
    ],
    'price': {
      'min': 5,
      'max': 192,
      'histogram': [
        for (final c in [16, 1, 2, 0, 0, 1, 0, 0, 0, 0, 0, 3, 3, 0, 0, 3]) {'from': 0, 'to': 0, 'count': c},
      ],
      'buckets': [
        {'min': null, 'max': 10, 'label': 'أقل من 10', 'count': 15},
        {'min': 10, 'max': 125, 'label': '10 – 125', 'count': 8},
        {'min': 125, 'max': null, 'label': '125+', 'count': 6},
      ],
    },
    'promoted': [
      {'group': 'life', 'value': 'young', 'label': 'قطط صغيرة', 'icon': 'kitten', 'count': 29},
      {'group': 'life', 'value': 'adult', 'label': 'بالغة', 'icon': 'cat_adult', 'count': 347},
      {'group': 'texture', 'value': 'pouch', 'label': 'أظرف', 'icon': 'pouch', 'count': 8},
      {'group': 'flavor', 'value': 'chicken', 'label': 'دجاج', 'icon': 'chicken', 'count': 15},
      {'group': 'flavor', 'value': 'tuna', 'label': 'تونة', 'icon': 'tuna', 'count': 13},
    ],
    'relax': [
      if (duck) {'group': 'flavor', 'value': 'duck', 'label': 'بط', 'count': 29},
      if (duck && kitten) {'group': 'life', 'value': 'young', 'label': 'قطط صغيرة', 'count': 11},
    ],
  });
}

class _FakeCatalog implements CatalogRepository {
  @override
  Future<ListingResult> products(ListingQuery query, int page) async {
    final duck = query.isSelected('flavor', 'duck');
    final kitten = query.isSelected('life', 'young');
    final total = duck && kitten ? 0 : (kitten ? 29 : 382);
    return ListingResult(
      products: total == 0
          ? const []
          : [
              _p(11400, 'د. كلاودرز بيست سيلكشن رقم 1 أظرف دجاج للقطط الصغيرة 85غ', 9.18),
              _p(11736, 'فيلاين قو رو باتيه سلمون القطبي مع البروكلي للقطط الصغيرة 90غ', 7.27),
              _p(17090, 'اكانا معلبات دجاج وسمك للقطط الصغيرة 85غ', 6.64),
              _p(14059, 'ناتشرال كود معلبات بالدجاج للقطط الصغيرة 85غ', 6.56),
            ],
      total: total,
      pages: 1,
      page: page,
      facets: _facets(query),
      sortOptions: const [
        SortOption(key: 'recommended', label: 'الأنسب لك', icon: 'spark'),
        SortOption(key: 'price', label: 'الأقل سعرًا', icon: 'price_low'),
      ],
      context: const ListingContext(
        node: CategoryNode(id: 128, slug: 'wet', name: 'الطعام الرطب', count: 382),
        parent: CategoryNode(id: 108, slug: 'food', name: 'طعام', count: 530),
        chipsAreSiblings: true,
        chips: [
          CategoryNode(id: 128, slug: 'wet', name: 'الطعام الرطب', count: 382),
          CategoryNode(id: 109, slug: 'dry', name: 'الطعام الجاف', count: 87),
          CategoryNode(id: 135, slug: 'milk', name: 'الحليب والسوائل', count: 33),
          CategoryNode(id: 138, slug: 'kit', name: 'طعام القطط الصغيرة', count: 55),
        ],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The empty state's «نبّهني إذا وصل…» — records what it was asked to watch.
class _FakePush implements PushRepository {
  final watched = <(ListingQuery, String)>[];

  @override
  Future<bool> filterWatching(ListingQuery query) async => false;

  @override
  Future<bool> watchFilter(ListingQuery query, {required String label}) async {
    watched.add((query, label));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late LocalStore _store;
final _push = _FakePush();

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

Widget _page(Brightness brightness) {
  final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
  Widget phone(Widget child, {double height = 1100}) => SizedBox(
        width: 393,
        height: height,
        child: MediaQuery(
          data: MediaQueryData(padding: const EdgeInsets.only(top: 44), disableAnimations: true, size: Size(393, height)),
          child: child,
        ),
      );
  const kittenWet = ListingQuery(category: 'wet');
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      eventsBufferProvider.overrideWithValue(_SilentEvents()),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      catalogRepositoryProvider.overrideWithValue(_FakeCatalog()),
      pushRepositoryProvider.overrideWithValue(_push),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: theme,
      home: ColoredBox(
        color: brightness == Brightness.dark ? const Color(0xFF0A0C0B) : const Color(0xFFE9ECE8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            phone(const ListingScreen(query: kittenWet, title: 'الطعام الرطب')),
            const SizedBox(width: 24),
            phone(
              height: 844,
              Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    clipBehavior: Clip.antiAlias,
                    child: FacetSheet(
                      query: const ListingQuery(category: 'wet', filters: {'life': {'young'}}),
                      facets: _facets(const ListingQuery(filters: {'life': {'young'}})),
                      total: 29,
                      initialGroup: 'flavor',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            phone(const ListingScreen(query: ListingQuery(category: 'wet', filters: {'flavor': {'duck'}}), title: 'الطعام الرطب')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadBrandFonts();
    SharedPreferences.setMockInitialValues({
      'pets.household.v1': jsonEncode([
        {'species': 'cat', 'name': 'لولو'},
      ]),
      'pets.life.g0': 'young',
    });
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  for (final brightness in Brightness.values) {
    testWidgets('listing filters sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3 + 48, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_page(brightness));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await _decode(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/listing_filters_sheet_${brightness.name}.png'));
    });
  }

  testWidgets('the empty state watches the picks, in words', (tester) async {
    tester.view.physicalSize = const Size(393 * 3 + 48, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page(Brightness.light));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    final button = find.textContaining('نبّهني إذا وصل');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(seconds: 1));
    expect(_push.watched.single.$1.filters, {'flavor': {'duck'}, 'life': {'young'}});
    expect(_push.watched.single.$2, contains('بط'));
    expect(find.text('سننبّهك أول ما يصل'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
