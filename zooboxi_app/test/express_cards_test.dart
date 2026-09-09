import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

/// The six express forms, each drawn at every phone width, text scale and
/// language the app ships, with the worst content the store can hand them: a
/// name that runs past two lines, a five-figure price with a struck original,
/// a «يبدأ من» prefix, a sold-out line, a brand, a chip. A form that clips at
/// 130% type is a form that clips for the customer who needs it most.

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
  name: 'ويلنس ويمزيس مكافآت فرشاة اسنان لعناية الأسنان 12 قطعة للكلاب متوسطة الحجم 420غ',
  brand: brand == null ? null : BrandRef(name: brand),
  price: 12345.5,
  regularPrice: onSale ? 19999 : 12345.5,
  onSale: onSale,
  priceFrom: variable,
  stockStatus: oos ? 'outofstock' : 'instock',
  stockQty: qty,
  isVariable: variable,
  badge: const ProductBadge(type: 'hot', label: 'الأكثر طلباً', icon: '🔥'),
  deliveryChip: chip ? const DeliveryChip(tier: 'express', label: 'خلال ساعتين اليوم') : null,
);

final _products = [
  _product(id: 1, brand: 'Zolux', chip: true, onSale: true),
  _product(id: 2, onSale: true, qty: 3),
  _product(id: 3, variable: true, brand: 'Royal Canin'),
  _product(id: 4, oos: true, brand: 'Wellness'),
  _product(id: 5, qty: 1, chip: true, brand: 'Princess'),
  _product(id: 6),
  _product(id: 7, onSale: true, brand: 'Applaws'),
];

Future<bool> _add(ProductCard product) async => true;

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
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: widget!,
    ),
    home: Scaffold(body: child),
  ),
);

Widget _page() => Builder(
  builder: (context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: ReorderStrip(
          slot: PersonalSlot(
            kind: 'buyagain',
            title: 'اشتريته سابقاً',
            products: _products,
            hints: const {1: ReorderHint(lastOrderedDays: 5), 2: ReorderHint(due: true)},
          ),
          products: _products,
          onAdd: _add,
        ),
      ),
      ...TrendingMosaic.slivers(context, title: 'رائج الآن', products: _products, onAdd: _add),
      SliverToBoxAdapter(child: PicksRail(title: 'مختارة لك', products: _products, onAdd: _add)),
      SliverToBoxAdapter(child: RankedList(title: 'الأكثر مبيعاً', products: _products, onAdd: _add)),
      SliverToBoxAdapter(
        child: ClearanceBand(title: 'التصفية', products: _products, onAdd: _add, tags: true),
      ),
      ...ArrivalsWall.slivers(context, title: 'وصل حديثاً', products: _products, onAdd: _add),
    ],
  ),
);

void main() {
  for (final size in const [Size(375, 812), Size(393, 852), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        testWidgets(
          'six forms have no overflow at ${size.width}pt, scale $scale, ${locale.languageCode}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(_harness(locale, scale, _page()));
            await tester.pump();
            expect(tester.takeException(), isNull);

            // Scroll the whole page so every sliver gets laid out once.
            final scrollable = find.byType(Scrollable).first;
            for (var i = 0; i < 12; i++) {
              await tester.drag(scrollable, const Offset(0, -500));
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  testWidgets('the chart shows six rows and no more', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        const Locale('ar'),
        1.0,
        SingleChildScrollView(
          child: RankedList(title: 'الأكثر مبيعاً', products: _products, onAdd: _add),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('7'), findsNothing);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('the leaderboard features the first product and ranks the rest', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        const Locale('ar'),
        1.0,
        Builder(
          builder: (context) => CustomScrollView(
            slivers: TrendingMosaic.slivers(
              context,
              title: 'رائج الآن',
              products: _products.take(3).toList(),
              onAdd: _add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FeatureTile), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('الأعلى طلباً اليوم'), findsOneWidget);
  });

  testWidgets('a wall tile with no photo still shows its sticker and price', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        const Locale('en'),
        1.0,
        Builder(
          builder: (context) => CustomScrollView(
            slivers: ArrivalsWall.slivers(context, title: 'New in', products: _products.take(3).toList()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('New'), findsNWidgets(3));
    expect(find.byType(ArrivalTile), findsNWidgets(3));
  });
}
