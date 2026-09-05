import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/widgets/product_card.dart';
import 'package:zooboxi_app/core/widgets/product_card_metrics.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/catalog/presentation/pet_palette.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/pet_section.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

ProductCard _product({
  required int id,
  String? brand,
  bool onSale = false,
  bool variable = false,
  bool oos = false,
  int? qty,
  bool chip = false,
}) => ProductCard(
  id: id,
  name:
      'ويلنس ويمزيس مكافآت فرشاة اسنان لعناية الأسنان 12 قطعة للكلاب متوسطة الحجم 420غ',
  brand: brand == null ? null : BrandRef(name: brand),
  price: 12345.5,
  regularPrice: onSale ? 19999 : 12345.5,
  onSale: onSale,
  priceFrom: variable,
  stockStatus: oos ? 'outofstock' : 'instock',
  stockQty: qty,
  isVariable: variable,
  badge: const ProductBadge(type: 'hot', label: 'الأكثر طلباً', icon: '🔥'),
  deliveryChip: chip
      ? const DeliveryChip(tier: 'express', label: 'خلال ساعتين اليوم')
      : null,
);

final _products = [
  _product(id: 1, brand: 'Zolux', chip: true),
  _product(id: 2, onSale: true, qty: 3),
  _product(id: 3, variable: true, brand: 'Royal Canin'),
  _product(id: 4, oos: true, brand: 'Wellness'),
  _product(id: 5, qty: 1, chip: true, brand: 'Princess'),
  _product(id: 6),
];

Widget _harness(Locale locale, double textScale, Widget child) => ProviderScope(
  child: MaterialApp(
    locale: locale,
    theme: AppTheme.light(locale),
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: widget!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  for (final size in const [Size(375, 812), Size(393, 852), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        testWidgets(
          'grid + rail have no overflow at ${size.width}pt, scale $scale, ${locale.languageCode}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _harness(
                locale,
                scale,
                Builder(
                  builder: (context) => CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: ProductCardMetrics.gridSpacing,
                                crossAxisSpacing:
                                    ProductCardMetrics.gridSpacing,
                                mainAxisExtent: ProductCardMetrics.gridExtent(
                                  context,
                                ),
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => ProductCardView(
                              product: _products[i],
                              onAdd: (_) async => true,
                            ),
                            childCount: _products.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Builder(
                            builder: (context) => PetSection(
                              palette: PetPalette.resolve(
                                context,
                                icon: '🐱',
                                index: 0,
                              ),
                              revealed: true,
                              pet: CategoryNode(
                                id: 107,
                                slug: 'cats',
                                name: 'قطط',
                                icon: '🐱',
                                count: 2190,
                                children: [
                                  for (var i = 0; i < 8; i++)
                                    CategoryNode(
                                      id: i,
                                      slug: 'c\$i',
                                      name: 'المكافآت والفيتامينات للقطط',
                                      count: 300,
                                    ),
                                ],
                              ),
                              onOpen: (_, _) {},
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ProductRailView(
                          title: 'رائج الآن',
                          products: _products,
                          animate: false,
                          onAdd: (_) async => true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
