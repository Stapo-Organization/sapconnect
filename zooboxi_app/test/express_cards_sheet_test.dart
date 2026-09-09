import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/clearance_band.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/arrivals_wall.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/picks_rail.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/ranked_list.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/reorder_strip.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/express_cards/trending_mosaic.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// The six express forms drawn the way the customer sees them — the real
/// Arabic face, both themes, one tall page per theme.
///
/// A *design* golden — refresh with
/// `flutter test test/express_cards_sheet_test.dart --update-goldens`.

ProductCard _p(int id, String name, double price, {String? brand, double? was, bool oos = false, bool chip = false, bool from = false}) =>
    ProductCard(
      id: id,
      name: name,
      brand: brand == null ? null : BrandRef(name: brand),
      price: price,
      regularPrice: was ?? price,
      onSale: was != null,
      priceFrom: from,
      stockStatus: oos ? 'outofstock' : 'instock',
      deliveryChip: chip ? const DeliveryChip(tier: 'express', label: 'خلال ساعتين') : null,
    );

final _products = [
  _p(1, 'رويال كانين طعام جاف للقطط البالغة ٢ كجم', 89, brand: 'Royal Canin', chip: true),
  _p(2, 'أبلوز معلبات تونا للقطط ٧٠ غ', 6.5, brand: 'Applaws', was: 9),
  _p(3, 'رمل كلامبينغ برائحة اللافندر ١٠ لتر', 42, brand: 'Ever Clean', from: true),
  _p(4, 'ويلنس مكافآت أسنان للكلاب ٤٢٠ غ', 35, brand: 'Wellness', oos: true),
  _p(5, 'برو بلان طعام جاف للكلاب الصغيرة ٣ كجم', 129, brand: 'Pro Plan', was: 159),
  _p(6, 'لعبة فأر بالكاتنيب للقطط', 12, brand: 'Zolux'),
  _p(7, 'شامبو للقطط بالألوفيرا ٢٥٠ مل', 28, brand: 'Bioline', was: 40),
];

Future<bool> _add(ProductCard product) async => true;

Widget _page(Brightness brightness) {
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(const Locale('ar'))
      : AppTheme.light(const Locale('ar'));
  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Builder(
            builder: (context) => CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: ReorderStrip(
                    slot: PersonalSlot(
                      kind: 'buyagain',
                      title: 'اشتريته سابقاً',
                      products: _products,
                      hints: const {1: ReorderHint(lastOrderedDays: 12), 2: ReorderHint(due: true)},
                    ),
                    products: _products,
                    onAdd: _add,
                    onSeeAll: () {},
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ...TrendingMosaic.slivers(context, title: 'رائج الآن', products: _products.take(5).toList(), onAdd: _add, onSeeAll: () {}),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: PicksRail(title: 'مختارة لك', products: _products, onAdd: _add)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: RankedList(title: 'الأكثر مبيعاً', products: _products, onAdd: _add, onSeeAll: () {})),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: ClearanceBand(title: 'التصفية', products: _products.where((p) => p.onSale).toList(), onAdd: _add, tags: true)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ...ArrivalsWall.slivers(context, title: 'وصل حديثاً', products: _products.take(6).toList(), onAdd: _add, onSeeAll: () {}),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBrandFonts);

  for (final brightness in Brightness.values) {
    testWidgets('express cards sheet ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393, 2560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ar'),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: _page(brightness),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/express_cards_sheet_${brightness.name}.png'),
      );
    });
  }
}
