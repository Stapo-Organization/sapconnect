import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/presentation/pet_palette.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/pet_section.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/pet_strip.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

CategoryNode _pet({int kids = 5}) => CategoryNode(
      id: 107,
      slug: 'cats',
      name: 'قطط',
      icon: '🐱',
      count: 2190,
      children: [
        for (var i = 0; i < kids; i++)
          CategoryNode(id: i, slug: 'c$i', name: i == 0 ? 'طعام' : 'مستلزمات القطط $i', count: 100 + i),
      ],
    );

Widget _app(Widget child, {double width = 393}) => MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.light(const Locale('ar')),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: SizedBox(width: width, child: child)),
        ),
      ),
    );

void main() {
  testWidgets('a revealed board lays out its band and every department card', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(
      builder: (context) => PetSection(
        pet: _pet(),
        palette: PetPalette.resolve(context, icon: '🐱', index: 0),
        revealed: true,
        onOpen: (_, _) {},
      ),
    )));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('طعام'), findsOneWidget);
    expect(tester.getSize(find.text('طعام')).height, greaterThan(0));
    for (var i = 1; i < 5; i++) {
      expect(find.text('مستلزمات القطط $i'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pet strip fits its chips, selected or not', (tester) async {
    final pets = [for (var i = 0; i < 4; i++) _pet(kids: 0)];
    await tester.pumpWidget(_app(PetStrip(pets: pets, active: 0, onSelect: (_) {})));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(PetStrip(pets: pets, active: 2, onSelect: (_) {})));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
