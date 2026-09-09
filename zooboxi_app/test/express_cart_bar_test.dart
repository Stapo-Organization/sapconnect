import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/shell/express_cart_bar.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// On زوبكسي the basket is a destination: you browse, you collect, you go to
/// it when you are done. On a two-hour shelf it is the running total of an
/// errand, and its absence was most of why إكسبريس still read as a store.

Future<void> _pump(WidgetTester tester, CartGlance glance) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: ExpressCartBarPreview(glance: glance),
        ),
      ),
    );

void main() {
  group('when the basket bar belongs on screen', () {
    test('إكسبريس, with something in it', () {
      expect(
        ExpressCartBar.shows(express: true, path: '/home', count: 3),
        isTrue,
      );
    });

    test('never on زوبكسي — the difference is the point', () {
      expect(
        ExpressCartBar.shows(express: false, path: '/home', count: 3),
        isFalse,
      );
    });

    test('never empty', () {
      expect(
        ExpressCartBar.shows(express: true, path: '/home', count: 0),
        isFalse,
      );
    });

    test('never on the basket, or on the way to paying for it', () {
      for (final path in ['/cart', '/checkout', '/checkout/payment']) {
        expect(
          ExpressCartBar.shows(express: true, path: path, count: 3),
          isFalse,
          reason: path,
        );
      }
      // A product page is not the basket, however it is spelled.
      expect(
        ExpressCartBar.shows(express: true, path: '/product/12', count: 3),
        isTrue,
      );
    });
  });

  group('what it says', () {
    testWidgets('the count as a counter and the money beside it',
        (tester) async {
      await _pump(tester, const CartGlance(count: 3, subtotal: 85));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('السلة'), findsOneWidget);
      expect(find.textContaining('85'), findsOneWidget);
    });

    testWidgets('a long basket still fits one row', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, const CartGlance(count: 128, subtotal: 12450.75));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });

  group('the glance is a value', () {
    test('a basket answer that moved neither number is the same glance', () {
      expect(const CartGlance(count: 3, subtotal: 85),
          const CartGlance(count: 3, subtotal: 85));
      expect(const CartGlance(count: 3, subtotal: 85).hashCode,
          const CartGlance(count: 3, subtotal: 85).hashCode);
    });

    test('one that moved either is not', () {
      expect(const CartGlance(count: 3, subtotal: 85),
          isNot(const CartGlance(count: 4, subtotal: 85)));
      expect(const CartGlance(count: 3, subtotal: 85),
          isNot(const CartGlance(count: 3, subtotal: 90)));
    });
  });
}
