import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/core/widgets/paginated_grid.dart';
import 'package:zooboxi_app/core/widgets/product_card.dart';
import 'package:zooboxi_app/core/widgets/product_card_foot.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

ProductCard _p(int id) => ProductCard.fromJson({
      'id': id,
      'name': 'منتج تجريبي $id',
      'item_code': 'P$id',
      'price': 25.5,
      'regular_price': 30.0,
      'on_sale': true,
      'stock_status': 'instock',
      'stock_qty': 20,
      'is_variable': false,
      'wishlisted': false,
    });

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('bag button fires onAdd on a bare card', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(
      Center(
        child: SizedBox(
          width: 180,
          child: ProductCardView(
            product: _p(1),
            onAdd: (_) async {
              fired++;
              return true;
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final overlay = find.byType(ProductCardAddOverlay);
    expect(overlay, findsOneWidget);
    await tester.tap(overlay, warnIfMissed: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(fired, 1, reason: 'bare card: onAdd must fire');
  });

  testWidgets('bag button fires onAdd inside PaginatedProductGrid', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(
      PaginatedProductGrid(
        resetKey: 'k',
        zone: 't',
        fetchPage: (page) async => ListingResult(
          products: [_p(1), _p(2)],
          total: 2,
          pages: 1,
          page: 1,
        ),
        onAdd: (_) async {
          fired++;
          return true;
        },
      ),
    ));
    // Let the fetch + entrance animation fully settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final overlays = find.byType(ProductCardAddOverlay);
    expect(overlays, findsNWidgets(2));
    await tester.tap(overlays.first, warnIfMissed: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(fired, 1, reason: 'grid card: onAdd must fire');
  });
}
