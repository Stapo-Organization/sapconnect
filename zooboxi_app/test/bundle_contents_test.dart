import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/product/presentation/widgets/bundle_contents.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// «محتويات البكج» is the bundle page's answer to "what am I getting" — these
/// lock the three ways that answer can go wrong: a component the server can
/// no longer resolve, a size it cannot vouch for, and a gift that stops
/// looking like one.

Widget _host(Widget child, {Locale locale = const Locale('ar')}) => MaterialApp(
      locale: locale,
      theme: AppTheme.light(locale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: child),
    );

BundleComponent _c(
  int id,
  String name, {
  int qty = 1,
  String role = 'member',
  String? weight,
}) =>
    BundleComponent(id: id, name: name, qty: qty, role: role, weightLabel: weight);

void main() {
  test('components parse from the pdp payload, dropping unresolvable rows', () {
    final detail = ProductDetail.fromJson({
      'id': 32624,
      'name': 'بكج',
      'bundle': {
        'components': [
          {'id': 11, 'name': 'اكانا معلبات دجاج', 'qty': 6, 'role': 'gift', 'weight_label': '85 غ'},
          {'id': 12, 'name': 'أبلاوز طعام جاف', 'qty': 1, 'weight_label': '6 كجم'},
          // A row the server could not resolve to a live product: no id, no
          // name — it must never become a card that taps into nothing.
          {'id': 0, 'name': '', 'qty': 3},
        ],
      },
    });

    expect(detail.bundleComponents, hasLength(2));
    expect(detail.bundleComponents.first.isGift, isTrue);
    expect(detail.bundleComponents.first.qty, 6);
    expect(detail.bundleComponents.last.weightLabel, '6 كجم');
  });

  test('a missing quantity still counts as one piece', () {
    final parsed = BundleComponent.listFrom([
      {'id': 9, 'name': 'منتج', 'qty': 0},
    ]);
    expect(parsed.single.qty, 1);
  });

  testWidgets('every component shows its count, and a gift says so', (tester) async {
    await tester.pumpWidget(_host(BundleContents(components: [
      _c(11, 'اكانا معلبات دجاج للقطط', qty: 6, role: 'gift', weight: '85 غ'),
      _c(12, 'أبلاوز طعام جاف للقطط', weight: '6 كجم'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('×6'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);
    expect(find.text('هدية'), findsOneWidget);
    expect(find.text('85 غ'), findsOneWidget);
    expect(find.text('6 كجم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a size the server cannot vouch for is simply absent', (tester) async {
    await tester.pumpWidget(_host(BundleContents(components: [
      _c(21, 'منتج بلا وزن معروف', qty: 4),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('×4'), findsOneWidget);
    // No placeholder, no "0 غ" — silence beats a guess.
    expect(find.textContaining('غ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list draws nothing at all', (tester) async {
    await tester.pumpWidget(_host(const BundleContents(components: [])));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
    expect(find.textContaining('محتويات'), findsNothing);
  });
}
