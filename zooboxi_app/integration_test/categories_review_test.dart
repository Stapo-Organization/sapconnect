// A visual review harness, not a regression test: boots the categories
// screen against the live store on a simulator and screenshots the journey
// (pet strip → boards → a department listing with its sibling chips) so the
// design can be reviewed frame by frame without a device in hand.
//
//   SCREENSHOT_DIR=… flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/categories_review_test.dart -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/presentation/categories_screen.dart';
import 'package:zooboxi_app/features/catalog/presentation/listing_screen.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/pet_section.dart';
import 'package:zooboxi_app/features/catalog/presentation/widgets/pet_strip.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(LocalStore store, {required Brightness brightness}) {
    const locale = Locale('ar');
    final router = GoRouter(
      initialLocation: '/categories',
      routes: [
        GoRoute(
          path: '/categories',
          builder: (_, _) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/listing',
          builder: (_, state) => ListingScreen(
            title: state.uri.queryParameters['title'] ?? '',
            query: ListingQuery.fromJson(state.uri.queryParameters),
          ),
        ),
        GoRoute(path: '/search', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/product/:id', builder: (_, _) => const Scaffold()),
      ],
    );
    return ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: brightness == Brightness.light
            ? AppTheme.light(locale)
            : AppTheme.dark(locale),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [locale],
      ),
    );
  }

  Future<void> settle(WidgetTester tester, [int ms = 2500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('categories journey', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    // The owner reviews in Arabic; the simulator's device language is English.
    await store.setLocaleCode('ar');

    await tester.pumpWidget(harness(store, brightness: Brightness.light));
    await settle(tester, 5000);
    await shot(tester, '01_cats_top');

    for (final section in tester.widgetList<PetSection>(
      find.byType(PetSection),
    )) {
      debugPrint(
        '[review] ${section.pet.name}: ${section.pet.children.length} departments, revealed=${section.revealed}',
      );
    }

    // The pet chips are the strip's InkWells, in pet order.
    Finder chip(int i) => find
        .descendant(of: find.byType(PetStrip), matching: find.byType(InkWell))
        .at(i);

    await tester.tap(chip(1));
    await settle(tester, 1600);
    await shot(tester, '02_dogs_board');

    await tester.tap(chip(2));
    await settle(tester, 1600);
    await shot(tester, '03_birds_board');

    await tester.tap(chip(3));
    await settle(tester, 1600);
    await shot(tester, '04_small_board');

    // Back to the top, then into the cats' first wide card (food).
    await tester.tap(chip(0));
    await settle(tester, 1600);
    final food = find.text('طعام').first;
    await tester.tap(food);
    await settle(tester, 4000);
    await shot(tester, '05_listing_food_chips');

    // Hop to a sibling department from the chip row.
    await tester.tap(find.text('صحة القطط').first);
    await settle(tester, 4000);
    await shot(tester, '06_listing_sibling');

    // Dark mode, top of the page.
    await tester.pumpWidget(harness(store, brightness: Brightness.dark));
    await settle(tester, 5000);
    await shot(tester, '07_cats_top_dark');
  });
}
