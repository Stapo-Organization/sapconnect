// Review goldens for «مين معك في البيت؟» — regenerate with
//   flutter test test/household_journey_sheet_test.dart --update-goldens
// and LOOK at them: the picker, the sign with the name on it, and the home the
// answer arranges.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/core/widgets/rail.dart';
import 'package:zooboxi_app/core/widgets/section_header.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/household_invite.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/household_welcome.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/shop_for_bar.dart';
import 'package:zooboxi_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

import 'support/brand_fonts.dart';

Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
}

void _mockLocation() {
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async => switch (call.method) {
        'checkPermission' => 2,
        'isLocationServiceEnabled' => true,
        _ => null,
      });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

Widget _app(LocalStore store, {required Widget home, GoRouter? router}) {
  Widget wrap(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
  return ProviderScope(
    overrides: [localStoreProvider.overrideWithValue(store)],
    child: router != null
        ? MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            locale: const Locale('ar'),
            theme: AppTheme.light(const Locale('ar')),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: wrap,
          )
        : MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            theme: AppTheme.light(const Locale('ar')),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: wrap,
            home: home,
          ),
  );
}

void main() {
  setUpAll(loadBrandFonts);

  testWidgets('the household step — picked, then named', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.locale': 'ar'});
    final store = LocalStore(await SharedPreferences.getInstance());
    _mockLocation();
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      store,
      home: const SizedBox.shrink(),
      router: GoRouter(initialLocation: '/onboarding', routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/home', builder: (_, _) => const SizedBox.shrink()),
      ]),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قطط'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('أضف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كلاب'));
    await tester.pumpAndSettle();
    await _decode(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/household_picker.png'));

    await tester.tap(find.text('التالي · 3 حيوانات'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'مشمش');
    await tester.pumpAndSettle();
    await tester.tap(find.text('بنت'));
    await tester.pumpAndSettle();
    await _decode(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/household_name.png'));
  });

  testWidgets('the home the answer arranges', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pets.household.v1': '[{"species":"cat","name":"مشمش","sex":"f"},{"species":"cat","name":"لولو"},{"species":"dog","name":"بندق"}]',
      'pets.shopping_for': 'g0',
    });
    final store = LocalStore(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(393 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      store,
      home: Scaffold(
        body: ShelfLook(
          endCard: true,
          child: ListView(
            padding: const EdgeInsets.only(top: 40),
            children: const [
              ShopForBar(),
              SizedBox(height: 8),
              HouseholdWelcome(),
              SizedBox(height: 20),
              ShelfLook(
                endCard: true,
                nap: true,
                child: ProductRailView(
                  title: 'مختار لـمشمش',
                  animate: false,
                  products: [
                    ProductCard(id: 1, name: 'ويلنس كور أكل جاف للقطط', image: null, price: 89),
                    ProductCard(id: 2, name: 'أبلاوز ظرف تونة للقطط 70 غ', image: null, price: 4.95),
                    ProductCard(id: 3, name: 'إينابا تشورو مكافأة سائلة', image: null, price: 9.5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _decode(tester);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/household_home.png'));
  });

  testWidgets('the invitation for everyone already past the welcome', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(393 * 2, 320 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      store,
      home: const Scaffold(body: Padding(padding: EdgeInsets.only(top: 40), child: HouseholdInvite())),
    ));
    await tester.pumpAndSettle();
    await _decode(tester);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/household_invite.png'));
  });
}
