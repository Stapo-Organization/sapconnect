import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/features/brand/presentation/brand_screen.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The brand page has to look *finished* on the payload the server actually
/// sends today: a name, a logo that is often missing, some categories and a
/// product count. Hero art, tagline and story are the exception, not the rule.
///
/// So these pump the bare payload — no hero, no logo, no tagline, no story —
/// and check the page still has an identity, a working department filter and
/// the brand's own picks above its catalogue.

const String _slug = 'applaws';

ProductCard _p(int id) => ProductCard(id: id, name: 'P$id', itemCode: 'C$id', price: 10);

// The chips row shows imaged departments only, so the fixtures carry art.
CategoryNode _c(int id, String slug, String name, int count) =>
    CategoryNode(id: id, slug: slug, name: name, count: count, image: 'https://x/c$id.png');

BrandPage _page() => BrandPage(
      brand: const BrandSummary(slug: _slug, name: 'Applaws', logo: null),
      productCount: 80,
      categories: [
        _c(107, 'cat-main', 'قطط', 64),
        _c(108, 'dog-main', 'كلاب', 12),
        _c(109, 'treats', 'مكافآت', 4),
      ],
      products: [_p(1), _p(2), _p(3), _p(4)],
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

  testWidgets('a bare brand still gets an identity, departments and picks',
      (tester) async {
    final catalog = _FakeCatalog();
    await _pump(tester, _host(_page(), catalog));

    // Identity: the name, and — with no logo — the brand's own initial rather
    // than the generic paw, on the tile AND on the «الكل» chip's circle.
    expect(find.text('Applaws'), findsWidgets);
    expect(find.text('A'), findsNWidgets(2));
    // The one fact this payload can state honestly.
    expect(find.text('80 منتجًا'), findsOneWidget);

    // «الكل» plus one chip per department.
    expect(find.text('الكل'), findsOneWidget);
    for (final name in const ['قطط', 'كلاب', 'مكافآت']) {
      expect(find.text(name), findsOneWidget);
    }

    // The curated rail leads, the whole catalogue pages underneath it.
    expect(find.text('مختارات Applaws'), findsOneWidget);
    expect(find.byType(ProductRailView), findsOneWidget);
    expect(find.text('كل منتجات Applaws'), findsOneWidget);
    expect(find.text('نتيجتان'), findsOneWidget, reason: 'the scope states its size');

    expect(catalog.queries.single.brand, _slug);
    expect(catalog.queries.single.category, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a department chip re-queries in place instead of leaving the brand',
      (tester) async {
    final catalog = _FakeCatalog();
    await _pump(tester, _host(_page(), catalog));

    await tester.tap(find.text('قطط'));
    await tester.pumpAndSettle();

    expect(catalog.queries.last.brand, _slug, reason: 'still inside the brand');
    expect(catalog.queries.last.category, 'cat-main');
    // Inside a department the brand's own picks would be showing cat food above
    // a dog shelf, so the rail stands down.
    expect(find.byType(ProductRailView), findsNothing);
    // The selected chip *is* the heading inside a department — repeating the
    // name over the grid would be the page talking to itself.
    expect(find.text('قطط'), findsOneWidget);
    expect(find.text('كل منتجات Applaws'), findsNothing);
    expect(find.text('نتيجتان'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // …and back to «الكل» brings it back, without a second page of the old query.
    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();

    expect(catalog.queries.last.category, isNull);
    expect(find.text('مختارات Applaws'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fully synced boutique kit paints its extra layers', (tester) async {
    final page = BrandPage(
      brand: const BrandSummary(slug: _slug, name: 'Applaws', accent: '#0d9488'),
      boutique: true,
      tagline: 'طعام طبيعي بلا حشو',
      story: 'ولدت في بريطانيا من فكرة واحدة: لحم حقيقي فقط.',
      country: 'المملكة المتحدة',
      founded: '1997',
      productCount: 80,
      tiles: const [BrandTile(image: 'https://x/1.jpg', headline: 'وجبات رطبة')],
      categories: [_c(107, 'cat-main', 'قطط', 64)],
      products: [_p(1), _p(2)],
    );

    await _pump(tester, _host(page, _FakeCatalog()));

    expect(find.text('طعام طبيعي بلا حشو'), findsOneWidget);
    expect(find.text('المملكة المتحدة'), findsOneWidget);
    expect(find.text('منذ 1997'), findsOneWidget);
    expect(find.text('وجبات رطبة'), findsOneWidget);
    expect(find.textContaining('ولدت في بريطانيا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the live payload maps onto the model, empty strings and all', () {
    final page = BrandPage.fromJson(_slug, {
      'code': '1513',
      'slug': _slug,
      'name': 'Applaws',
      'boutique': false,
      'hero': null,
      'logo': 'https://x/logo.png',
      'kit': {'accent': '#0d9488', 'accent_dark': null, 'gold': null, 'tagline': ''},
      'story': {'lead': '', 'country': '', 'founded': '', 'mood': ''},
      'tiles': [
        {'image': '', 'headline': 'ignored — a headline is not a tile'},
      ],
      'products': [
        {'id': 7, 'name': 'P7', 'item_code': 'C7', 'price': 12},
      ],
      'categories': [
        {'id': 107, 'slug': 'cat-main', 'name': 'قطط', 'count': 64},
      ],
      'product_count': 80,
    });

    expect(page.name, 'Applaws');
    expect(page.brand.code, '1513');
    expect(page.brand.accent, '#0d9488');
    expect(page.boutique, isFalse);
    // Every empty string folds to null so the screen can test one thing.
    expect(page.hero, isNull);
    expect(page.tagline, isNull);
    expect(page.story, isNull);
    expect(page.country, isNull);
    expect(page.founded, isNull);
    expect(page.accentDark, isNull);
    expect(page.tiles, isEmpty);
    expect(page.categories.single.slug, 'cat-main');
    expect(page.products.single.id, 7);
    expect(page.productCount, 80);
  });
}
