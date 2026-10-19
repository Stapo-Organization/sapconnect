import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/brand/presentation/brand_screen.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «الواجهة» (the owner's pick, 2026-09-24) has to look finished on two very
/// different payloads: a bare brand (a name, often no logo, a count) and a
/// brand with its identity on file (colour, country, founding year, mood,
/// who it is for, curated lines, a bigger-pack saving). These pump both and
/// check what each promises: the stage and the facts that exist, the line
/// tiles filtering the grid in place, and the story one tap away.

const String _slug = 'applaws';

ProductCard _p(int id) => ProductCard(id: id, name: 'P$id', itemCode: 'C$id', price: 10);

BrandPage _bare() => BrandPage(
      brand: const BrandSummary(slug: _slug, name: 'Applaws', logo: null),
      productCount: 80,
      products: [_p(1), _p(2), _p(3), _p(4)],
    );

BrandPage _inaba() => BrandPage(
      brand: const BrandSummary(slug: _slug, name: 'INABA', accent: '#F39200'),
      hasKit: true,
      accentDark: '#E2001A',
      tagline: 'المكافأة اليابانية الأولى عالميًا التي تُلعق',
      lead: 'أصحاب القطط المدللون الذين يحبون لحظة القرب والتدليل',
      country: 'اليابان',
      founded: '1958',
      specialty: 'للقطط',
      mood: const ['لطيف', 'شهي', 'قريب'],
      species: 'cat',
      productCount: 121,
      shelfTotal: 121,
      inStock: 92,
      products: [_p(1), _p(2), _p(3)],
      lines: const [
        BrandShelf(group: 'line', key: 'inaba_churu', name: 'تشورو', count: 70),
        BrandShelf(group: 'line', key: 'inaba_dashi', name: 'داشي ديلايت', count: 23),
      ],
      value: BrandValue(
        perUnit: true,
        product: _p(9),
        bigLabel: '50 × 14 جم',
        bigEach: 2.03,
        smallLabel: '4 × 14 جم',
        smallEach: 2.93,
        saving: 31,
      ),
    );

/// The grid pages imperatively off the repository, so the repository is what
/// gets faked — the same seam the real screen uses.
class _FakeCatalog implements CatalogRepository {
  final List<ListingQuery> queries = [];

  @override
  Future<ListingResult> products(ListingQuery query, int page) async {
    queries.add(query);
    return ListingResult(products: [_p(50), _p(51)], total: 2, pages: 1, page: page);
  }

  /// Everything else on the repository is out of this screen's reach; calling
  /// one is a test bug, so let it throw rather than answering with a fake.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Widget _host(BrandPage page, _FakeCatalog catalog) => ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(_store),
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        catalogRepositoryProvider.overrideWithValue(catalog),
        brandPageProvider(_slug).overrideWithValue(AsyncValue.data(page)),
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
        home: const BrandScreen(slug: _slug, name: 'Applaws'),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  testWidgets('a bare brand still gets a stage, its name and its whole range', (tester) async {
    final catalog = _FakeCatalog();
    await _pump(tester, _host(_bare(), catalog));

    // No logo: the plate carries the name itself.
    expect(find.text('Applaws'), findsWidgets);
    // No identity on file: no story to open, no lines to show.
    expect(find.byTooltip('عن Applaws'), findsNothing);
    expect(find.text('كل منتجات Applaws'), findsOneWidget);
    expect(find.text('منتجان'), findsOneWidget, reason: 'the scope states its size');

    expect(catalog.queries.single.brand, _slug);
    expect(catalog.queries.single.filters, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a line tile narrows the grid in place, and lets go on a second tap', (tester) async {
    final catalog = _FakeCatalog();
    await _pump(tester, _host(_inaba(), catalog));

    expect(find.text('خطوط INABA'), findsOneWidget);
    expect(find.text('العبوة الكبيرة أوفر'), findsOneWidget);

    await tester.tap(find.text('تشورو'));
    await tester.pumpAndSettle();

    expect(catalog.queries.last.brand, _slug, reason: 'still inside the brand');
    expect(catalog.queries.last.filters['line'], {'inaba_churu'});
    // The saving belongs to the whole brand, not to a filtered view of it.
    expect(find.text('العبوة الكبيرة أوفر'), findsNothing);
    expect(find.text('كل منتجات INABA'), findsNothing);

    // Another line moves the ring rather than stacking.
    await tester.tap(find.text('داشي ديلايت'));
    await tester.pumpAndSettle();
    expect(catalog.queries.last.filters['line'], {'inaba_dashi'});

    await tester.tap(find.text('داشي ديلايت'));
    await tester.pumpAndSettle();
    expect(catalog.queries.last.filters['line'] ?? const <String>{}, isEmpty);
    expect(find.text('العبوة الكبيرة أوفر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a brand with its identity on file paints its facts and opens its story', (tester) async {
    await _pump(tester, _host(_inaba(), _FakeCatalog()));

    expect(find.text('المكافأة اليابانية الأولى عالميًا التي تُلعق'), findsOneWidget);
    expect(find.text('اليابان · منذ 1958'), findsOneWidget);
    expect(find.text('للقطط'), findsOneWidget);
    expect(find.text('لطيف'), findsOneWidget);

    await tester.tap(find.text('عن INABA').first);
    await tester.pumpAndSettle();

    expect(find.text('لمن صُنعت'), findsOneWidget);
    expect(find.textContaining('أصحاب القطط المدللون'), findsOneWidget);
    expect(find.text('تأسست INABA'), findsOneWidget);
    expect(find.text('تسوّق كل INABA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the live payload maps onto the model, empty strings and all', () {
    final page = BrandPage.fromJson(_slug, {
      'code': '199',
      'slug': _slug,
      'name': 'INABA',
      'boutique': false,
      'has_kit': true,
      'hero': null,
      'logo': 'https://x/logo.png',
      'kit': {'accent': '#F39200', 'accent_dark': '#E2001A', 'gold': null, 'tagline': ''},
      'story': {'lead': '', 'country': 'اليابان', 'founded': '1958', 'mood': 'لطيف·شهي', 'mood_words': ['لطيف', 'شهي'], 'specialty': 'للقطط'},
      'species': 'cat',
      'tiles': [
        {'image': '', 'headline': 'ignored — a headline is not a tile'},
      ],
      'products': [
        {'id': 7, 'name': 'P7', 'item_code': 'C7', 'price': 12},
      ],
      'categories': [],
      'product_count': 121,
      'lines': [
        {'group': 'line', 'key': 'inaba_churu', 'name': 'تشورو', 'count': 70, 'image': 'https://x/c.png', 'icon': null},
        {'group': 'line', 'key': '', 'name': 'broken'},
      ],
      'shelves': [],
      'value': {
        'mode': 'unit',
        'product': {'id': 9, 'name': 'P9', 'item_code': 'C9', 'price': 101.27},
        'big': {'label': '50 × 14 جم', 'each': 2.03},
        'small': {'label': '4 × 14 جم', 'each': 2.93, 'id': 3},
        'saving': 31,
      },
      'shelf_total': 73,
      'in_stock': 70,
    });

    expect(page.brand.code, '199');
    expect(page.brand.accent, '#F39200');
    expect(page.hasKit, isTrue);
    expect(page.tagline, isNull, reason: 'an empty string folds to null');
    expect(page.lead, isNull);
    expect(page.country, 'اليابان');
    expect(page.founded, '1958');
    expect(page.mood, ['لطيف', 'شهي']);
    expect(page.specialty, 'للقطط');
    expect(page.species, 'cat');
    expect(page.tiles, isEmpty);
    expect(page.lines.single.key, 'inaba_churu', reason: 'a line without a key is dropped');
    expect(page.shelvesToShow, isEmpty, reason: 'one line is not a choice');
    expect(page.value!.perUnit, isTrue);
    expect(page.value!.saving, 31);
    expect(page.value!.product.id, 9);
    expect(page.shelfTotal, 73);
    expect(page.inStock, 70);
  });
}
