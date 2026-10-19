// A visual review harness, not a regression test: «حسابي» as picked on the
// canvas (direction D), in the states it ships in — a guest, a member with a
// cat and a dog and a parcel on its way, a member who has not ordered yet —
// plus the settings page and dark mode, screenshotted from the real app.
//
//   SCREENSHOT_DIR=… flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/account_review_test.dart -d <simulator>
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/app.dart';
import 'package:zooboxi_app/app/router.dart';
import 'package:zooboxi_app/app/settings/app_settings.dart';
import 'package:zooboxi_app/core/analytics/analytics_service.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/auth/data/auth_repository.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_repository.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/orders/data/live_tracking.dart';
import 'package:zooboxi_app/features/orders/data/order_models.dart';
import 'package:zooboxi_app/features/orders/data/orders_repository.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

class _QuietAnalytics extends AnalyticsService {
  @override
  Future<bool> trackingUndecided() async => false;

  @override
  Future<void> requestTrackingAuthorization() async {}
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

  testWidgets('account review', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await store.setLocaleCode('ar');
    await store.setThemeMode(ThemeMode.light);
    await store.setWelcomeSeen();

    LoyaltySummary? summary;
    ActiveOrder? active;

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          analyticsProvider.overrideWithValue(_QuietAnalytics()),
          loyaltySummaryProvider.overrideWith((ref) async {
            ref.watch(sessionProvider);
            return summary;
          }),
          topActiveOrderProvider.overrideWith((ref) => active),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const ZooboxiApp();
          },
        ),
      ),
    );
    await settle(tester, 4000);

    // A guest first — before anyone signs in.
    ctx().go('/account');
    await settle(tester, 3000);
    await shot(tester, '01_guest');

    final auth = container.read(authRepositoryProvider);
    await auth.sendOtp('0500000000');
    final result = await auth.verifyOtp(
      phone: '0500000000',
      otp: '4471',
      platform: 'ios',
      deviceName: 'Account review',
    );
    await container.read(sessionProvider.notifier).establish(token: result.token, user: result.user);

    // A member who has not ordered yet.
    summary = const LoyaltySummary(tier: TierInfo(key: 'start', name: 'بداية الرحلة', next: NextTier(key: 'friend', name: 'صديق', min: 2)));
    container.invalidate(loyaltySummaryProvider);
    await settle(tester, 3000);
    await shot(tester, '02_new_member');

    // A member with a cat, a dog, and a parcel on its way.
    final catalog = container.read(catalogRepositoryProvider);
    Future<ProductCard?> first(String q) async {
      final found = await catalog.products(ListingQuery(q: q, perPage: 6), 1);
      for (final p in found.products) {
        if (p.image != null) return p;
      }
      return null;
    }

    final catFood = await first('أبلاوز جاف قطط');
    final dogTreat = await first('زولكس سويتيز كلاب');
    const lulu = PetRef(id: 1, name: 'لولو', species: PetSpecies.cat);
    const max = PetRef(id: 2, name: 'ماكس', species: PetSpecies.dog);
    final now = DateTime.now();
    summary = LoyaltySummary(
      paws: const PawsBalance(balance: 1240, pending: 120),
      tier: const TierInfo(key: 'friend', name: 'صديق', orders12m: 4, min: 3, next: NextTier(key: 'special', name: 'مميّز', min: 7)),
      counters: const LoyaltyCounters(ordersTotal: 9),
      pets: const [
        Pet(id: 1, name: 'لولو', species: PetSpecies.cat, ageLabel: 'سنتان'),
        Pet(id: 2, name: 'ماكس', species: PetSpecies.dog, birthdayInDays: 6),
      ],
      supply: SupplyBlock(items: [
        if (catFood != null)
          SupplyItem(product: catFood, kind: 'dry', pet: lulu, daysLeft: 4, cycleDays: 30, runsOutAt: now.add(const Duration(days: 4))),
        if (dogTreat != null)
          SupplyItem(product: dogTreat, kind: 'dry', pet: max, daysLeft: 12, cycleDays: 20, runsOutAt: now.add(const Duration(days: 12))),
      ]),
      referral: const ReferralSummary(code: 'SARA24', url: 'https://store.zooboxi.com/r/SARA24', rewardPaws: 200, rewarded: 1),
    );
    active = ActiveOrder(
      order: OrderSummary(
        id: 1,
        number: '33120',
        status: 'processing',
        total: 82.3,
        date: now,
        itemsPreview: [
          if (catFood != null) OrderItemPreview(name: catFood.name, image: catFood.image),
          if (dogTreat != null) OrderItemPreview(name: dogTreat.name, image: dogTreat.image),
        ],
      ),
    );
    container.invalidate(loyaltySummaryProvider);
    container.invalidate(topActiveOrderProvider);
    await settle(tester, 4000);
    await shot(tester, '03_member_top');

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -620));
    await settle(tester, 2500);
    await shot(tester, '04_member_bottom');

    unawaited(ctx().push('/account/settings'));
    await settle(tester, 2500);
    await shot(tester, '05_settings');
    ctx().pop();
    await settle(tester, 1000);

    await container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 900));
    await settle(tester, 3000);
    await shot(tester, '06_member_dark');
    await container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.light);
  });
}
