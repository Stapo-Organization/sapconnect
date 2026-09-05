import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/widgets/qty_stepper.dart';
import 'package:zooboxi_app/core/widgets/totals_card.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/free_shipping_bar.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/gift_cart_line.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The gift line has to be *unmistakably* a gift and unmistakably not
/// editable: a stepper on a reward, or a price where "مجانًا" belongs, would
/// both suggest a transaction that isn't happening.

Widget _app(Widget child, {Locale locale = const Locale('ar')}) => MaterialApp(
      locale: locale,
      theme: AppTheme.light(locale),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: 380, child: child)),
        ),
      ),
    );

const CartItem _gift = CartItem(
  key: 'gift-1',
  productId: 55,
  name: '🎁 هدية · لعبة قطط',
  qty: 1,
  unitPrice: 0,
  lineTotal: 0,
  isGift: true,
  grantId: 123,
  lockedQty: true,
);

void main() {
  testWidgets('a gift line shows «مجانًا» with no stepper', (tester) async {
    await tester.pumpWidget(_app(GiftCartLineView(item: _gift, onRemove: () {})));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('مجانًا'), findsOneWidget);
    expect(find.text('هدية'), findsOneWidget);
    expect(find.text('🎁 هدية · لعبة قطط'), findsOneWidget);

    // The two controls a reward must never carry.
    expect(find.byType(QtyStepper), findsNothing);
    expect(find.textContaining('0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing it releases the claim rather than deleting a line',
      (tester) async {
    var released = 0;
    await tester.pumpWidget(
      _app(GiftCartLineView(item: _gift, onRemove: () => released++)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(released, 1);
  });

  testWidgets('while the release is in flight the control is a spinner',
      (tester) async {
    await tester.pumpWidget(
      _app(GiftCartLineView(item: _gift, onRemove: () {}, busy: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('in English the gift reads "Free"', (tester) async {
    await tester.pumpWidget(
      _app(const GiftCartLineView(item: _gift), locale: const Locale('en')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Gift'), findsOneWidget);
  });

  testWidgets('the totals card carries the paws this basket will earn',
      (tester) async {
    await tester.pumpWidget(
      _app(const TotalsCard(
        totals: CartTotals(subtotal: 240, shipping: 0, total: 240),
        pawsToEarn: 240,
      )),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ستكسب 240 بصمة'), findsOneWidget);
  });

  testWidgets('no paws line when the basket earns nothing', (tester) async {
    await tester.pumpWidget(
      _app(const TotalsCard(totals: CartTotals(subtotal: 0, total: 0))),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('بصمة'), findsNothing);
  });

  testWidgets('a waived fee says why it was waived', (tester) async {
    await tester.pumpWidget(
      _app(const FreeShippingBar(
        freeShipping: FreeShipping(min: 200, remaining: 60),
        expressFreeReason: 'reward',
      )),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('توصيل سريع مجاني بمكافأتك'), findsOneWidget);
  });

  testWidgets('a granted free delivery stops nudging toward the threshold',
      (tester) async {
    await tester.pumpWidget(
      _app(const FreeShippingBar(
        freeShipping: FreeShipping(min: 200, remaining: 60),
        freeDeliveryReason: 'tier',
      )),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('توصيل مجاني بفضل مستواك'), findsOneWidget);
    expect(find.textContaining('باقي'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
