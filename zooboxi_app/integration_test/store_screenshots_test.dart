// The App Store screenshots, taken from the real app against the live store.
//
// Not a regression test: a journey through the screens a customer would use
// to decide, signed in as the App Review account, on the 6.9" iPhone Apple
// asks for. Every frame is the app as it ships — no mock data, no frames.
//
//   SCREENSHOT_DIR=build/appstore flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart \
//     -d "iPhone 16 Pro Max"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/app.dart';
import 'package:zooboxi_app/app/router.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/account/presentation/address_editor_screen.dart';
import 'package:zooboxi_app/features/auth/data/auth_repository.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';

/// A real express address — the King Fahd branch's own neighbourhood — so the
/// storefront opens on the 2-hour shelf with stock behind every card.
class _FixedLocation extends LocationController {
  @override
  LocationState build() => const LocationState(
        location: ZbLocation(
          lat: 24.7480,
          lng: 46.6650,
          city: 'الرياض',
          district: 'الملك فهد',
          deliveryType: 'express',
          warehouseCode: 'RUH010',
          promiseLabel: 'خلال ساعتين',
          label: 'المنزل',
        ),
      );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  BuildContext ctx() => rootNavigatorKey.currentContext!;

  testWidgets('app store journey', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await store.setLocaleCode('ar');
    await store.setThemeMode(ThemeMode.light);
    await store.setWelcomeSeen();

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          locationProvider.overrideWith(_FixedLocation.new),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const ZooboxiApp();
          },
        ),
      ),
    );
    // Splash → home.
    await settle(tester, 4000);

    // Sign in as the App Review account: the same OTP path a customer walks,
    // minus the SMS (the store hands that number a fixed code).
    final auth = container.read(authRepositoryProvider);
    await auth.sendOtp('0500000000');
    final result = await auth.verifyOtp(
      phone: '0500000000',
      otp: '4471',
      platform: 'ios',
      deviceName: 'App Store screenshots',
    );
    await container.read(sessionProvider.notifier).establish(
          token: result.token,
          user: result.user,
        );
    ctx().go('/home');
    await settle(tester, 5000);
    await shot(tester, '01_home_express');

    // A product page: the first card on the first rail of the shelf we are on.
    final home = await container.read(catalogRepositoryProvider).home(shelf: 'express');
    final rail = home.rails.firstWhere((r) => r.products.isNotEmpty);
    final product = rail.products.first;
    unawaited(ctx().push('/product/${product.id}'));
    await settle(tester, 4000);
    await shot(tester, '02_product');
    ctx().pop();
    await settle(tester, 800);

    // Categories.
    ctx().go('/categories');
    await settle(tester, 3500);
    await shot(tester, '03_categories');

    // The cart, with something in it.
    await container.read(cartControllerProvider.notifier).add(productId: product.id);
    if (rail.products.length > 1) {
      await container.read(cartControllerProvider.notifier).add(productId: rail.products[1].id);
    }
    ctx().go('/cart');
    await settle(tester, 3500);
    await shot(tester, '04_cart');

    // The account, then its notification settings.
    ctx().go('/account');
    await settle(tester, 3000);
    await shot(tester, '05_account');

    unawaited(ctx().push('/notifications'));
    await settle(tester, 2500);
    await shot(tester, '06_notifications');
    ctx().pop();
    await settle(tester, 600);

    // عائلة زوبوكسي.
    unawaited(ctx().push('/family'));
    await settle(tester, 3500);
    await shot(tester, '07_family');
    ctx().pop();
    await settle(tester, 600);

    // The map: a new address, pin stage.
    unawaited(Navigator.of(ctx(), rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const AddressEditorScreen(contactOptional: true),
      ),
    ));
    await settle(tester, 4500);
    await shot(tester, '08_map');
  });
}
