import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/shelf/shelf_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/brand/presentation/brand_screen.dart';
import 'package:zooboxi_app/features/brand/presentation/widgets/brand_about_sheet.dart';
import 'package:zooboxi_app/features/brand/presentation/widgets/brand_palette.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// «الواجهة» — the brand page the owner approved on 2026-09-24 — as a design
/// sheet: INABA (its real products, prices and kit) on زوبكسي and on
/// إكسبريس, a brand without curated lines (the automatic split), and the
/// «عن INABA» sheet. Real product photos come from test/fixtures/brand via a
/// fake HTTP client, so the sheet shows the page as the phone will.
///
/// Refresh: `flutter test test/brand_page_sheet_test.dart --update-goldens`, then look.

const _fixtures = 'test/fixtures/brand';

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
      image: 'https://img.test/p$id.webp',
    );

final _inabaGrid = [
  _p(12105, 'اينابا تشورو دجاج ولحم بقري متنوع 20 ظرف × 14غ', 42.42),
  _p(11950, 'اينابا تشورو متنوع تونا + متنوع دجاج للفرو والجلد 50×14غ', 101.27),
  _p(11974, 'اينابا تشورو هريسة دجاج مع سلطعون 4×14غ', 11.73),
  _p(11983, 'اينابا تشورو جيلي دجاج 4×15غ', 11.73),
];

class _FakeCatalog implements CatalogRepository {
  @override
  Future<ListingResult> products(ListingQuery query, int page) async =>
      ListingResult(products: _inabaGrid, total: 121, pages: 1, page: page);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BrandPage _inaba({int total = 121, int inStock = 92}) => BrandPage(
      brand: const BrandSummary(slug: 'inaba', name: 'INABA', code: '199', logo: 'https://img.test/logo-inaba.webp', accent: '#F39200'),
      hasKit: true,
      accentDark: '#E2001A',
      tagline: 'المكافأة اليابانية الأولى عالميًا التي تُلعق',
      lead: 'أصحاب القطط المدللون الذين يحبون لحظة القرب والتدليل بإطعام قطتهم باليد، ويهتمون بمكونات طبيعية يابانية عالية الجودة',
      country: 'اليابان',
      founded: '1958',
      specialty: 'للقطط',
      mood: const ['لطيف', 'شهي', 'قريب', 'مرح'],
      species: 'cat',
      productCount: 121,
      shelfTotal: total,
      inStock: inStock,
      products: [
        _p(12105, 'اينابا تشورو دجاج ولحم بقري متنوع 20 ظرف × 14غ', 42.42),
        _p(11974, 'اينابا تشورو هريسة دجاج مع سلطعون 4×14غ', 11.73),
        _p(12026, 'اينابا داشي ديلايت اكواب دجاج مع تونة ومحار 70غ', 50.10),
      ],
      lines: const [
        BrandShelf(group: 'line', key: 'inaba_churu', name: 'تشورو', count: 70, image: 'https://img.test/p11974.webp'),
        BrandShelf(group: 'line', key: 'inaba_dashi', name: 'داشي ديلايت', count: 23, image: 'https://img.test/p12026.webp'),
        BrandShelf(group: 'line', key: 'inaba_grill', name: 'فيليه بالمرق', count: 14, image: 'https://img.test/p12086.webp'),
        BrandShelf(group: 'line', key: 'inaba_ciao', name: 'سياو سوجوي', count: 6, image: 'https://img.test/p11296.webp'),
      ],
      value: BrandValue(
        perUnit: true,
        product: _p(11950, 'اينابا تشورو متنوع تونا + متنوع دجاج للفرو والجلد 50×14غ', 101.27),
        bigLabel: '50 × 14 جم',
        bigEach: 2.03,
        smallLabel: '4 × 14 جم',
        smallEach: 2.93,
        saving: 31,
      ),
    );

/// A brand with its kit but no curated lines: the page splits it by pet.
BrandPage _zolux() => BrandPage(
      brand: const BrandSummary(slug: 'zolux', name: 'Zolux', code: '239', logo: 'https://img.test/logo-zolux.webp', accent: '#E2001A'),
      hasKit: true,
      accentDark: '#A50014',
      tagline: 'عناية عائلية لكل أليف منذ 1933',
      country: 'فرنسا',
      founded: '1933',
      specialty: 'لكل الأليفة',
      mood: const ['ودود', 'عائلي', 'دافئ'],
      species: 'multi',
      productCount: 572,
      shelfTotal: 572,
      inStock: 488,
      products: [
        _p(11296, 'زولكس سويتيز مكافآت دجاج للكلاب', 7.62),
        _p(12086, 'زولكس مكافآت العصي المقرمشة', 13.59),
      ],
      shelves: const [
        BrandShelf(group: 'species', key: 'dog', name: 'كلاب', count: 169, icon: 'dog_adult'),
        BrandShelf(group: 'species', key: 'cat', name: 'قطط', count: 159, icon: 'cat_adult'),
        BrandShelf(group: 'species', key: 'bird', name: 'طيور', count: 87, icon: 'budgie'),
        BrandShelf(group: 'species', key: 'small', name: 'حيوانات صغيرة', count: 67, icon: 'hamster'),
      ],
    );

class _Shelf extends ShelfController {
  _Shelf(this.shelf);
  final Shelf shelf;
  @override
  Shelf build() => shelf;
}

late LocalStore _store;

Widget _phone(Widget child, {double height = 1560}) => SizedBox(
      width: 393,
      height: height,
      child: MediaQuery(
        data: MediaQueryData(padding: const EdgeInsets.only(top: 47), disableAnimations: true, size: Size(393, height)),
        child: child,
      ),
    );

Widget _sheet(Brightness brightness) {
  final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
  Widget scope(Shelf shelf, Widget child) => ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(_store),
          eventsBufferProvider.overrideWithValue(_SilentEvents()),
          cartRepositoryProvider.overrideWithValue(StubCartRepository()),
          catalogRepositoryProvider.overrideWithValue(_FakeCatalog()),
          shelfProvider.overrideWith(() => _Shelf(shelf)),
          brandPageProvider('inaba').overrideWithValue(AsyncValue.data(shelf == Shelf.express ? _inaba(total: 73, inStock: 70) : _inaba())),
          brandPageProvider('zolux').overrideWithValue(AsyncValue.data(_zolux())),
        ],
        child: child,
      );

  return MaterialApp(
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
          _phone(scope(Shelf.all, const BrandScreen(slug: 'inaba', name: 'INABA'))),
          const SizedBox(width: 24),
          _phone(scope(Shelf.express, const BrandScreen(slug: 'inaba', name: 'INABA'))),
          const SizedBox(width: 24),
          _phone(scope(Shelf.all, const BrandScreen(slug: 'zolux', name: 'Zolux'))),
          const SizedBox(width: 24),
          _phone(
            scope(
              Shelf.all,
              Builder(
                builder: (context) => Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: 1000,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(size: const Size(393, 1160)),
                        child: BrandAboutSheet(
                          page: _inaba(),
                          palette: BrandPalette.of(context, _inaba()),
                          onShopAll: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Serves `https://img.test/<name>` from test/fixtures/brand — the product
/// photos and logos the store really sends for INABA and Zolux.
class _LocalImages extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

class _Client implements HttpClient {
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 5);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.url);
  final Uri url;

  @override
  Future<HttpClientResponse> close() async {
    final file = File('$_fixtures/${url.pathSegments.last}');
    return _Response(file.existsSync() ? file.readAsBytesSync() : const <int>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;

  @override
  int get statusCode => bytes.isEmpty ? 404 : 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([bytes]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await loadBrandFonts();
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
    HttpOverrides.global = _LocalImages();
  });

  for (final brightness in Brightness.values) {
    testWidgets('brand page sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 4 + 72, 1560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_sheet(brightness));
      await tester.pump(const Duration(milliseconds: 300));
      // Pictures come off the fake network and decode off the fake clock.
      for (var round = 0; round < 3; round++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element, onError: (_, _) {})
                .timeout(const Duration(seconds: 3), onTimeout: () {});
          }
        });
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/brand_page_sheet_${brightness.name}.png'));
    });
  }
}
