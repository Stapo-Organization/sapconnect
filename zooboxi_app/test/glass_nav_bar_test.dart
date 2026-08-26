import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/shell/glass_nav_bar.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The tab bar is the app's only permanent chrome, so the things that must
/// never regress are: all four destinations reachable, the highlight actually
/// following the tap, and the cart count still visible from anywhere in the
/// store — that badge is the app's confirmation that "add to cart" landed.

Widget _host({
  required List<int> taps,
  int cartCount = 0,
  Locale locale = const Locale('ar'),
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [cartCountProvider.overrideWithValue(cartCount)],
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.light(locale),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: GlassNavBar(
            index: taps.isEmpty ? 0 : taps.last,
            onSelect: (index) => setState(() => taps.add(index)),
          ),
        ),
      ),
    ),
  );
}

AlignmentDirectional _pill(WidgetTester tester) =>
    tester.widget<AnimatedAlign>(find.byKey(GlassNavBar.pillKey)).alignment
        as AlignmentDirectional;

void main() {
  testWidgets('all four destinations render and the highlight follows the tap',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(taps: taps));
    await tester.pumpAndSettle();

    for (final label in const ['الرئيسية', 'الأقسام', 'السلة', 'حسابي']) {
      expect(find.text(label), findsOneWidget);
    }

    // Tab 0 sits at the start edge — directional, so it is the *right* edge in
    // Arabic without the bar knowing anything about mirroring.
    expect(_pill(tester).start, -1);

    await tester.tap(find.text('الأقسام'));
    await tester.pumpAndSettle();

    expect(taps, [1]);
    expect(_pill(tester).start, closeTo(-1 / 3, 0.001));

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();

    expect(taps, [1, 3]);
    expect(_pill(tester).start, 1, reason: 'the last tab pins to the end edge');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cart badge reports the basket from every tab', (tester) async {
    await tester.pumpWidget(_host(taps: <int>[], cartCount: 3));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(_host(taps: <int>[], cartCount: 140));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget, reason: 'a three-digit count would not fit');

    await tester.pumpWidget(_host(taps: <int>[]));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing, reason: 'an empty basket says nothing');
  });

  // The bar floats *over* the store, so every tab screen has to know how much
  // room to leave under its last row. None of them hardcode it: Scaffold folds
  // the bar's height into the body's bottom padding and they read that. This
  // locks the mechanism the four branch screens depend on — if it ever stopped
  // propagating, the cart button and the last rail would slide under the glass.
  testWidgets('the floating bar hands its height to the page below it',
      (tester) async {
    double? bottomPadding;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cartCountProvider.overrideWithValue(0)],
        child: MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.light(const Locale('ar')),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            extendBody: true,
            body: Builder(
              builder: (context) {
                bottomPadding = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand();
              },
            ),
            bottomNavigationBar: GlassNavBar(index: 0, onSelect: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(bottomPadding, isNotNull);
    expect(bottomPadding, greaterThanOrEqualTo(GlassNavBar.barHeight));
  });

  // A fixed-height bar carrying live text in two languages is exactly the shape
  // that clips when someone turns their font size up.
  for (final scale in const [1.0, 1.3, 2.0]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets('survives text scale $scale, ${locale.languageCode}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(taps: <int>[], cartCount: 12, locale: locale, textScale: scale),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GlassNavBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
