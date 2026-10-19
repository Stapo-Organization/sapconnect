// The App Store screenshots, taken from the real app against the live store.
//
// Not a regression test: a journey through the screens a customer would use
// to decide, signed in as the App Review account, on the 6.9" iPhone Apple
// asks for. The framed marketing pages are composed from these raw frames.
//
//   SCREENSHOT_DIR=build/appstore/raw flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart \
//     -d "iPhone 16 Pro Max"
//
// The review account has no pet history, so the pet shelf and the «how long
// it lasts» line read a household written here from real catalog products.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/app.dart';
import 'package:zooboxi_app/app/router.dart';
import 'package:zooboxi_app/core/analytics/analytics_service.dart';
import 'package:zooboxi_app/core/location/location_controller.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/account/presentation/address_editor_screen.dart';
import 'package:zooboxi_app/features/auth/data/auth_repository.dart';
import 'package:zooboxi_app/features/cart/data/cart_controller.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

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

/// The system tracking sheet would sit over every frame after the first add.
class _QuietAnalytics extends AnalyticsService {
  @override
  Future<bool> trackingUndecided() async => false;

  @override
  Future<void> requestTrackingAuthorization() async {}
}

const _lulu = PetRef(id: 1, name: 'لولو', species: PetSpecies.cat);

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

    // Lulu's usual three, found in the live catalog.
    final shelf = <SupplyItem>[];
    ProductCard? food;
    var foodUnits = <int>[0];

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          locationProvider.overrideWith(_FixedLocation.new),
          analyticsProvider.overrideWithValue(_QuietAnalytics()),
          loyaltySummaryProvider.overrideWith((ref) async {
            final real = await ref.watch(loyaltyRepositoryProvider).summary();
            return LoyaltySummary(
              member: real.member,
              paws: real.paws,
              tier: real.tier,
              missions: real.missions,
              rewards: real.rewards,
              pets: real.pets,
              counters: real.counters,
              pendingOrders: real.pendingOrders,
              supply: SupplyBlock(items: shelf, dueCount: 1, total: shelf.length),
              subscriptions: real.subscriptions,
              birthday: real.birthday,
              referral: real.referral,
              stamps: real.stamps,
              care: real.care,
              nudges: real.nudges,
            );
          }),
          petLastsProvider.overrideWith((ref, id) async => id == food?.id
              ? PetLasts(pet: 'لولو', kind: 'dry', units: [
                  for (final v in foodUnits) (variationId: v, days: 38, perDay: 1.9),
                ])
              : null),
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

    final catalog = container.read(catalogRepositoryProvider);
    Future<ProductCard?> first(String q) async {
      final found = await catalog.products(ListingQuery(q: q, perPage: 6), 1);
      for (final p in found.products) {
        if (p.image != null && p.inStock) return p;
      }
      return null;
    }

    food = await first('أبلاوز جاف قطط');
    if (food != null) {
      final detail = await catalog.product(food.id);
      foodUnits = [0, for (final v in detail.variations) v.variationId];
    }
    final litter = await first('رمل قطط');
    final treat = await first('إينابا');
    final now = DateTime.now();
    for (final (product, kind, days) in [(food, 'dry', 4), (litter, 'litter', 9), (treat, 'treat', 12)]) {
      if (product == null) continue;
      shelf.add(SupplyItem(
        product: product,
        kind: kind,
        pet: _lulu,
        daysLeft: days,
        cycleDays: 30,
        runsOutAt: now.add(Duration(days: days)),
      ));
    }
    container.invalidate(loyaltySummaryProvider);

    ctx().go('/home');
    await settle(tester, 6000);
    await shot(tester, '01_home_express');

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await settle(tester, 2500);
    await shot(tester, '02_home_express_scrolled');

    // The product page — Lulu's food, with how long a bag lasts her.
    if (food != null) {
      unawaited(ctx().push('/product/${food.id}', extra: food));
      await settle(tester, 5000);
      await shot(tester, '03_product');
      ctx().pop();
      await settle(tester, 800);
    }

    // The cats' aisle.
    unawaited(ctx().push('/aisle/107?title=${Uri.encodeComponent('قطط')}'));
    await settle(tester, 5000);
    await shot(tester, '04_aisle_cats');
    ctx().pop();
    await settle(tester, 800);

    // A brand's own window.
    unawaited(ctx().push('/brand/applaws'));
    await settle(tester, 5000);
    await shot(tester, '05_brand');
    ctx().pop();
    await settle(tester, 800);

    // Bundles.
    unawaited(ctx().push('/bundles'));
    await settle(tester, 5000);
    await shot(tester, '06_bundles');
    ctx().pop();
    await settle(tester, 800);

    // Search, before a word is typed.
    unawaited(ctx().push('/listing?q=${Uri.encodeComponent('رمل قطط')}&title=${Uri.encodeComponent('رمل قطط')}'));
    await settle(tester, 4500);
    await shot(tester, '07_listing');
    ctx().pop();
    await settle(tester, 800);

    // Categories.
    ctx().go('/categories');
    await settle(tester, 3500);
    await shot(tester, '08_categories');

    // The cart, with Lulu's three in it.
    final cart = container.read(cartControllerProvider.notifier);
    for (final line in shelf) {
      try {
        await cart.add(productId: line.product.id);
      } catch (_) {
        // A size to choose first — the cart shows the others.
      }
    }
    ctx().go('/cart');
    await settle(tester, 4000);
    await shot(tester, '09_cart');

    // عائلة زوبوكسي.
    ctx().go('/account');
    await settle(tester, 3000);
    await shot(tester, '10_account');
    unawaited(ctx().push('/family'));
    await settle(tester, 4000);
    await shot(tester, '11_family');
    ctx().pop();
    await settle(tester, 600);

    // The map: a new address, pin stage.
    unawaited(Navigator.of(ctx(), rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const AddressEditorScreen(contactOptional: true),
      ),
    ));
    await settle(tester, 6000);
    await shot(tester, '12_map');
    Navigator.of(ctx(), rootNavigator: true).pop();
    await settle(tester, 800);

    // The same home after dark.
    await store.setThemeMode(ThemeMode.dark);
    container.invalidate(localStoreProvider);
    ctx().go('/home');
    await settle(tester, 4000);
    await shot(tester, '13_home_dark');

    // Leave the review account's basket as it was.
    for (final line in shelf) {
      final item = container.read(cartControllerProvider).value?.items.where((i) => i.productId == line.product.id);
      if (item != null && item.isNotEmpty) await cart.remove(item.first.key);
    }
  });
}
