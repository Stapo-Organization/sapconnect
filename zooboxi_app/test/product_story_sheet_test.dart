import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/product_story.dart';
import 'package:zooboxi_app/features/product/presentation/widgets/story/product_story_view.dart';
import 'package:zooboxi_app/features/product/presentation/widgets/story/story_sheets.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

/// «قصة المنتج» — the owner's pick «الألواح، ملوّن جريء» (2026-09-23), drawn
/// from a real store payload (جوسيرا باتيه, `test/fixtures/story_josera.json`):
/// highlights + facts, the tile grid, and the two sheets people open most.
/// A *design* golden: refresh with
/// `flutter test test/product_story_sheet_test.dart --update-goldens`, then look.

ProductStory _story([String name = 'josera']) {
  final json = jsonDecode(File('test/fixtures/story_$name.json').readAsStringSync()) as Map<String, dynamic>;
  return ProductStory.maybe(json['story'])!;
}

Widget _page(Brightness brightness, ProductStory story) {
  final theme = brightness == Brightness.dark ? AppTheme.dark(const Locale('ar')) : AppTheme.light(const Locale('ar'));
  Widget sheet(StorySection s) => Container(
        margin: const EdgeInsets.fromLTRB(12, 24, 12, 0),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(26),
        ),
        child: StorySectionBody(story: story, section: s, cartonUnits: 16),
      );

  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            StoryHighlights(story: story),
            const SizedBox(height: 24),
            ProductStoryTiles(story: story, cartonUnits: 16),
            if (story.section('feeding') != null) sheet(story.section('feeding')!),
            if (story.section('ingredients') != null) sheet(story.section('ingredients')!),
            if (story.section('feeding') == null) sheet(story.section('features')!),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBrandFonts);

  test('the store payload parses into every piece the page draws', () {
    final s = _story();
    expect(s.isUseful, isTrue);
    expect(s.highlights.map((h) => h.title), contains('خالٍ من الحبوب'));
    expect(s.facts.map((f) => f.kind), containsAll(['weight', 'protein', 'form', 'species']));
    expect(s.composition!.hasChart, isTrue);
    expect(s.composition!.centerValue, '70%');
    final f = s.feeding!;
    expect(f.rows, hasLength(4));
    // 16 pouches at 2.75 a day → about 6 days.
    expect(f.lasts(f.rows[f.defaultIndex], 16), (6, true));
    // No carton option → no promise.
    expect(f.lasts(f.rows[f.defaultIndex], 0), isNull);
    expect(s.section('analysis')!.percentRows.first, ('البروتين الخام', 10.8));
    expect(s.species, 'cat');
    expect(f.hasChart, isTrue);
    expect(f.chartMax, 4);
  });

  for (final (name, brightness) in [
    ('josera', Brightness.light),
    ('josera', Brightness.dark),
    ('tag', Brightness.light),
  ]) {
    testWidgets('product story sheet $name ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(393, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          debugShowCheckedModeBanner: false,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: _page(brightness, _story(name)),
        ),
      );
      // Asset images (the character, the logo) decode off the fake clock.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/product_story_sheet_${name}_${brightness.name}.png'),
      );
    });
  }
}
