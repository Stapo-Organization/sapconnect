// A visual review harness, not a regression test: opens real product pages
// against the live store on a simulator and screenshots «قصة المنتج».
//
//   SCREENSHOT_DIR=… flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/product_story_review_test.dart -d <simulator>
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
import 'package:zooboxi_app/features/product/presentation/product_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(LocalStore store, int id) {
    const locale = Locale('ar');
    final router = GoRouter(
      initialLocation: '/product/$id',
      routes: [
        GoRoute(
          path: '/product/:id',
          builder: (_, state) => ProductScreen(productId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    return ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: AppTheme.light(locale),
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

  testWidgets('product story pages', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await store.setLocaleCode('ar');
    await binding.convertFlutterSurfaceToImage();

    for (final id in [12237, 10763, 13393]) {
      await tester.pumpWidget(harness(store, id));
      await settle(tester, 6000);
      await binding.takeScreenshot('${id}_1');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, 1200);
      await binding.takeScreenshot('${id}_2');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, 1200);
      await binding.takeScreenshot('${id}_3');
    }
  });
}
