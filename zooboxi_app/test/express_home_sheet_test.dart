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
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/animal_pills.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/arrivals_wall.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/clearance_ticket.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/need_pockets.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/podium.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/promise_header.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';
import 'support/stub_cart.dart';

/// «الوعد» — the إكسبريس home the owner approved, drawn the way the customer
/// sees it: the promise header, the need pockets, the species pills, the
/// podium, the clearance ticket and the polaroid wall, in both themes.
///
/// A *design* golden — refresh with
/// `flutter test test/express_home_sheet_test.dart --update-goldens`.

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

ProductCard _p(int id, String name, double price, {String? brand, double? was, bool oos = false}) =>
    ProductCard(
      id: id,
      name: name,
      brand: brand == null ? null : BrandRef(name: brand),
      price: price,
      regularPrice: was ?? price,
      onSale: was != null,
      stockStatus: oos ? 'outofstock' : 'instock',
    );

final _products = [
  _p(1, 'برنسيس إكسلنس تونا للقطط ٧٠ غ', 6.5, brand: 'Princess'),
  _p(2, 'بيفار ملطّف رمل القطط ٤٠٠ غ', 24, brand: 'Beaphar'),
  _p(3, 'زولكس سويتيز مكافآت قطط', 9, brand: 'Zolux'),
  _p(4, 'فيليكس غو رو باتيه ٨٥ غ', 4.25, brand: 'Felyn Go', was: 7.5),
  _p(5, 'كاتي مالت معجون كرات الشعر', 21, brand: 'Bio PetActive', was: 36),
  _p(6, 'بيفار معجون فيتامينات للقطط', 18, brand: 'Beaphar', was: 29),
  _p(7, 'طوق صدر للقطط أزرق', 32),
  _p(8, 'حقيبة نقل للقطط والكلاب الصغيرة', 119),
  _p(9, 'فيلين غو حليب للقطط الصغيرة', 14, brand: 'Felyn Go'),
];

const _needs = [
  NeedNavItem(key: 'food', id: 1, slug: 'food', name: 'طعام رطب وجاف', icon: 'food'),
  NeedNavItem(key: 'litter', id: 2, slug: 'litter', name: 'رمل ونظافة', icon: 'litter'),
  NeedNavItem(key: 'treats', id: 3, slug: 'treats', name: 'مكافآت وأظرف', icon: 'treats'),
  NeedNavItem(key: 'health', id: 4, slug: 'health', name: 'صيدلية وعناية', icon: 'health'),
  NeedNavItem(key: 'toys', id: 5, slug: 'toys', name: 'ألعاب', icon: 'toys'),
];

const _animals = [
  AnimalNavItem(id: 1, slug: 'cats', name: 'قطط', icon: 'cat'),
  AnimalNavItem(id: 2, slug: 'dogs', name: 'كلاب', icon: 'dog'),
  AnimalNavItem(id: 3, slug: 'birds', name: 'طيور', icon: 'bird'),
  AnimalNavItem(id: 4, slug: 'fish', name: 'أسماك', icon: 'fish'),
  AnimalNavItem(id: 5, slug: 'small-pets', name: 'قوارض', icon: 'rodent'),
];

Future<bool> _add(ProductCard product) async => true;

late LocalStore _store;

Widget _page(Brightness brightness) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  final now = DateTime(2026, 9, 10, 14, 12);
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(_store),
      cartRepositoryProvider.overrideWithValue(StubCartRepository()),
      locationProvider.overrideWith(_At.new),
    ],
    child: Theme(
      data: theme,
      child: Builder(
        builder: (context) => ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              padding: const EdgeInsets.only(top: 44),
            ),
            child: Builder(
              builder: (context) => CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: PromiseHeader(scope: _scope, now: now)),
                  const SliverToBoxAdapter(child: SizedBox(height: 22)),
                  const SliverToBoxAdapter(child: AnimalPills(items: _animals, species: 'cat')),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  const SliverToBoxAdapter(child: NeedPockets(items: _needs)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Podium(title: 'الأكثر طلبًا على إكسبريس', products: _products.take(3).toList(), onAdd: _add, onSeeAll: () {}),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: ClearanceTicket(
                      title: 'تصفية الرفّ',
                      products: _products.where((p) => p.onSale).toList(),
                      onAdd: _add,
                      onSeeAll: () {},
                      hours: _scope.expressHours,
                      now: now,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ...ArrivalsWall.slivers(context, title: 'وصل حديثًا إلى إكسبريس', products: _products.skip(6).toList(), onAdd: _add, onSeeAll: () {}),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadBrandFonts();
    SharedPreferences.setMockInitialValues({});
    _store = LocalStore(await SharedPreferences.getInstance());
  });

  for (final brightness in Brightness.values) {
    testWidgets('express home sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393, 1900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await withClock(Clock.fixed(DateTime(2026, 9, 10, 14, 12)), () async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: _page(brightness),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/express_home_sheet_${brightness.name}.png'),
        );
      });
    });
  }
}
