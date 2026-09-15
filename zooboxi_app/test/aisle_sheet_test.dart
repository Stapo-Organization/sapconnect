import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/brand/presentation/brand_screen.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/catalog/presentation/aisle_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// The three pages the owner chose on 2026-09-15 — «الممرّ» (a species),
/// «الطبقات» (a department) and «البوتيك» (a brand) — side by side, in both
/// themes. A *design* golden: refresh with
/// `flutter test test/aisle_sheet_test.dart --update-goldens`, then look.

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

class _FakeCatalog implements CatalogRepository {
  @override
  Future<ListingResult> products(ListingQuery query, int page) async =>
      ListingResult(products: [_p(50, 'أبلاوز جاف دجاج مع السلمون', 19), _p(51, 'أبلاوز معلبات دجاج وخضار', 10.13)], total: 80, pages: 1, page: page);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductCard _p(int id, String name, double price, {double? was}) => ProductCard(
      id: id,
      name: name,
      itemCode: 'P$id',
      price: price,
      regularPrice: was ?? price,
      onSale: was != null,
      cutout: 'https://x/cut-$id.png',
    );

CategoryNode _c(int id, String name, int count, {String icon = ''}) =>
    CategoryNode(id: id, slug: 'c$id', name: name, count: count, icon: icon, image: 'https://x/$id.png');

Aisle _cats() => Aisle(
      node: _c(107, 'قطط', 2238, icon: '🐱'),
      bestsellers: [_p(1, 'سنال أظرف كريمي 5×15غ', 7), _p(2, 'زولكس سويتيز مكافآت دجاج', 0.95), _p(3, 'سينيور غاتو رمل 10 لتر', 28)],
      rows: [
        AisleRow(node: _c(108, 'طعام', 436), hasChildren: true, products: [_p(11, 'فيلاين قو حليب للقطط الصغيرة', 3.75), _p(12, 'برنسيس بريميوم معلبات دجاج', 3.85), _p(13, 'بايو بيت أكتيف بديل حليب', 25)]),
        AisleRow(node: _c(235, 'رمل القطط', 61), products: [_p(21, 'سينيور غاتو الوردي رمل مهد', 28), _p(22, 'ليندو كات العطر المزدوج', 14), _p(23, 'بايو ساند رمل مهد 10 لتر', 22, was: 29)]),
        AisleRow(node: _c(132, 'المكافآت والفيتامينات', 229), hasChildren: true, products: [_p(31, 'زولكس سويتيز مكافآت تونة', 0.95), _p(32, 'زولكس سويتيز مكافآت دجاج', 0.95), _p(33, 'بيفار معجون فيتامينات', 18)]),
      ],
    );

Aisle _food() => Aisle(
      node: _c(108, 'طعام', 530),
      parent: _c(107, 'قطط', 2238, icon: '🐱'),
      root: _c(107, 'قطط', 2238, icon: '🐱'),
      bestsellers: [_p(41, 'د. كلاودرز بيست سيلكشن', 8.75), _p(42, 'كت كات بديل الحليب', 26)],
      rows: [
        AisleRow(node: _c(109, 'الطعام الجاف', 87), products: [_p(51, 'سوليد جولد فت آز أ فيدل', 60), _p(52, 'أبلاوز طعام جاف دجاج', 19), _p(53, 'جوسيرا سينيور 2 كغ', 42)]),
        AisleRow(node: _c(128, 'الطعام الرطب', 382), products: [_p(61, 'برنسيس دجاج وأرز 70غ', 3.85), _p(62, 'د. كلاودرز معلبات تونة', 8.75), _p(63, 'أبلاوز صحن دجاج مع البط', 6.08)]),
        AisleRow(node: _c(135, 'الحليب والسوائل', 33), products: [_p(71, 'فيلاين قو حليب للقطط', 3.75), _p(72, 'بايو بيت أكتيف كيتن', 25), _p(73, 'كت كات بديل الحليب', 26)]),
      ],
    );

BrandPage _applaws() => BrandPage(
      brand: const BrandSummary(slug: 'applaws', name: 'Applaws', logo: 'https://x/applaws.png', accent: '#0F5C2E'),
      accentDark: '#1F7A45',
      tagline: 'مكوّنات طبيعية، بلا إضافات',
      country: 'بريطانيا',
      founded: '2006',
      productCount: 80,
      categories: [_c(107, 'قطط', 62), _c(114, 'كلاب', 18)],
      products: [_p(81, 'أبلاوز طعام جاف للقطط البالغة دجاج', 19), _p(82, 'ابلاوز صحن طعام رطب دجاج مع البط', 6.08), _p(83, 'أبلاوز معلبات دجاج وخضار مع الأرز', 10.13)],
    );

late LocalStore _store;

Widget _page(Brightness brightness) {
  final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
  Widget phone(Widget child) => SizedBox(
        width: 393,
        height: 1500,
        child: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44), disableAnimations: true, size: Size(393, 1500)),
          child: child,
        ),
      );
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      eventsBufferProvider.overrideWithValue(_SilentEvents()),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      catalogRepositoryProvider.overrideWithValue(_FakeCatalog()),
      aisleProvider('107').overrideWithValue(AsyncValue.data(_cats())),
      aisleProvider('108').overrideWithValue(AsyncValue.data(_food())),
      brandPageProvider('applaws').overrideWithValue(AsyncValue.data(_applaws())),
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
          children: [
            phone(const AisleScreen(aisleKey: '107', title: 'قطط')),
            const SizedBox(width: 24),
            phone(const AisleScreen(aisleKey: '108', title: 'طعام')),
            const SizedBox(width: 24),
            phone(const BrandScreen(slug: 'applaws', name: 'Applaws')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadBrandFonts();
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  for (final brightness in Brightness.values) {
    testWidgets('aisle sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3 + 48, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_page(brightness));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/aisle_sheet_${brightness.name}.png'));
    });
  }
}
