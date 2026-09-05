import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/free_shipping_bar.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/missions_strip.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/loyalty/presentation/family_hub_screen.dart';
import 'package:zooboxi_app/features/loyalty/presentation/ledger_screen.dart';
import 'package:zooboxi_app/features/loyalty/presentation/rewards_screen.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/scratch_card_view.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/data/pets_repository.dart';
import 'package:zooboxi_app/features/pets/data/care_models.dart';
import 'package:zooboxi_app/features/pets/presentation/pet_editor_screen.dart';
import 'package:zooboxi_app/features/pets/presentation/pet_profile_screen.dart';
import 'package:zooboxi_app/features/pets/presentation/pets_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The family program's screens, rendered with the real Arabic face so the
/// design can be judged as the customer sees it. A *design* golden:
///
///   flutter test test/family_screens_sheet_test.dart --update-goldens \
///     --dart-define=ZB_FONT_DIR=/path/to/tajawal/ttfs
///
/// Without the define the sheet still renders, in the test framework's box
/// font — good enough for layout, useless for judging type.

const String _fontDir = String.fromEnvironment('ZB_FONT_DIR');

Future<void> _loadFonts() async {
  if (_fontDir.isEmpty) return;
  final loader = FontLoader('ZbPreview');
  for (final file in ['Tajawal-Regular', 'Tajawal-Medium', 'Tajawal-Bold', 'Tajawal-ExtraBold']) {
    final f = File('$_fontDir/$file.ttf');
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

class _StubLedger extends LedgerController {
  _StubLedger(this._feed);
  final LedgerFeed _feed;
  @override
  Future<LedgerFeed> build() async => _feed;
}

ThemeData _theme() {
  final base = AppTheme.light(const Locale('ar'));
  if (_fontDir.isEmpty) return base;
  return base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'ZbPreview'));
}

Widget _host(Widget screen, {List<Override> overrides = const []}) => ProviderScope(
      overrides: [eventsBufferProvider.overrideWithValue(_SilentEvents()), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        theme: _theme(),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: widget!,
        ),
        home: screen,
      ),
    );

const _pets = [
  Pet(id: 7, name: 'أوريو', species: PetSpecies.cat, breed: 'شيرازي', ageLabel: 'سنتان', weightKg: 4.2, isComplete: true),
  Pet(id: 8, name: 'ريم', species: PetSpecies.dog, birthdayInDays: 3),
];

const _missions = [
  Mission(id: 1, key: 'profile', kind: 'profile', title: 'أكمل ملف عائلتك', body: 'أضف وزن صديقك وتاريخ ميلاده لنقترح عليك بدقة.', target: 1, progress: 1, state: 'rewarded', reward: MissionReward(paws: 100)),
  Mission(id: 2, key: 'first_app_order', kind: 'welcome', title: 'أول طلب من التطبيق', body: 'اطلب مرة واحدة من التطبيق واستلم مكافأة الترحيب.', target: 1, progress: 0, reward: MissionReward(paws: 150)),
  Mission(id: 3, key: 'frequency', kind: 'frequency', title: '3 طلبات هذا الشهر', body: 'اجمع بصمات إضافية عند إكمال طلبات الشهر.', target: 3, progress: 1, reward: MissionReward(paws: 300)),
  Mission(id: 4, key: 'try_new_brand', kind: 'trial', title: 'جرّب ماركة جديدة', body: 'اطلب صنفاً من ماركة لم يجرّبها صديقك من قبل.', target: 1, progress: 0, reward: MissionReward(paws: 150)),
];

const _express = Reward(id: 2, kind: 'express_free', title: 'ترقية توصيل سريع مجاني', titleEn: 'Free express upgrade', description: 'طلبك القادم يصلك بالتوصيل السريع بلا رسوم — داخل نطاق التوصيل السريع.', pawsCost: 250, valueSar: 15, validityDays: 21, minTier: 'new', redeemable: true);
const _delivery = Reward(id: 3, kind: 'free_delivery', title: 'توصيل مجاني بلا حد أدنى', titleEn: 'Free delivery', description: 'استخدمها في سلتك القادمة ولن تدفع رسوم توصيل مهما كان المبلغ.', pawsCost: 400, valueSar: 25, validityDays: 21, minTier: 'new', redeemable: true);
const _gift = Reward(id: 4, kind: 'gift_product', title: 'هدية صغيرة', titleEn: 'Small gift', description: 'مكافأة صغيرة تُضاف لسلتك مجاناً.', pawsCost: 600, valueSar: 25, validityDays: 21, minTier: 'new', redeemable: false, reasonAr: 'لم يُربط منتج بهذه الهدية بعد');

LoyaltySummary _summary({bool pending = true}) => LoyaltySummary(
      member: LoyaltyMember(joinedAt: DateTime(2026, 9, 5), referralCode: 'ZBUCNBN'),
      paws: const PawsBalance(balance: 1240),
      tier: const TierInfo(
        key: 'star',
        name: 'مميّز',
        c1: '#e8a765',
        c2: '#d48644',
        orders12m: 5,
        min: 4,
        next: NextTier(key: 'gold', name: 'ذهبي', min: 8, ordersNeeded: 3),
        perks: [
          TierPerk(key: 'free_min_150', text: 'الشحن المجاني من 150 ﷼ بدل 200', active: true, fromTier: 'star'),
          TierPerk(key: 'express_free_always', text: 'توصيل سريع مجاني دائماً', fromTier: 'gold'),
          TierPerk(key: 'free_delivery_always', text: 'توصيل مجاني بلا حد أدنى', fromTier: 'amb'),
          TierPerk(key: 'priority_support', text: 'أولوية في الدعم', fromTier: 'gold'),
          TierPerk(key: 'samples', text: 'عيّنات جديدة قبل الجميع', fromTier: 'amb'),
          TierPerk(key: 'whatsapp', text: 'خط واتساب مباشر', fromTier: 'amb'),
        ],
      ),
      missions: const MissionsBlock(items: _missions),
      rewards: const SummaryRewards(activeCount: 1, sealedScratch: [SealedScratch(id: 88, orderNumber: '32579')]),
      pets: _pets,
      pendingOrders: pending ? const [PendingOrder(id: 4102, number: '32601', paws: 118, isApp: true)] : const [],
      supply: const SupplyBlock(
        items: [
          SupplyItem(
            product: ProductCard(id: 501, name: 'رويال كانين قطط بالغة دجاج 2 كجم', image: null, price: 120),
            kind: 'dry',
            pet: PetRef(id: 7, name: 'مشمش', species: PetSpecies.cat),
            qtyLast: 1,
            cycleDays: 41,
            daysLeft: 4,
            status: 'soon',
            confidence: 'high',
            onTime: true,
            packKg: 2,
            buys: 3,
          ),
          SupplyItem(
            product: ProductCard(id: 502, name: 'رمل قطط متكتل برائحة اللافندر 10 كجم', image: null, price: 65),
            kind: 'litter',
            pet: PetRef(id: 7, name: 'مشمش', species: PetSpecies.cat),
            qtyLast: 1,
            cycleDays: 20,
            daysLeft: 13,
            status: 'ok',
            confidence: 'medium',
            packKg: 10,
            buys: 2,
            subscriptionId: 12,
          ),
        ],
        dueCount: 1,
        total: 2,
      ),
      subscriptions: const SubscriptionsBlock(
        active: 1,
        next: Subscription(
          id: 12,
          product: ProductCard(id: 502, name: 'رمل قطط متكتل برائحة اللافندر 10 كجم', image: null, price: 65),
          qty: 1,
          intervalDays: 21,
          daysUntil: 11,
          deliveries: 2,
          nextGiftIn: 1,
          pet: PetRef(id: 7, name: 'مشمش', species: PetSpecies.cat),
        ),
      ),
      referral: const ReferralSummary(code: 'ZBUCNBN', url: 'https://store.zooboxi.com/?ref=ZBUCNBN', rewarded: 1),
      stamps: const [
        StampCard(programId: 3, title: 'بطاقة رويال كانين', brandName: 'Royal Canin', unitsRequired: 6, minPackKg: 1.5, units: 4, remaining: 2),
      ],
    );

final _catalog = RewardsCatalog(
  catalog: const [_express, _delivery, _gift],
  grants: [
    const Grant(id: 5, reward: _express, state: 'active', source: 'redeem'),
    Grant(id: 6, reward: _delivery, state: 'pending', activatesOnOrder: const LoyaltyOrderRef(id: 4102, number: '32601'), expiresAt: DateTime(2026, 10, 1)),
  ],
);

List<Override> _member() => [
      isAuthenticatedProvider.overrideWithValue(true),
      loyaltySummaryProvider.overrideWith((ref) => Future.value(_summary())),
      loyaltyRewardsProvider.overrideWith((ref) => Future.value(_catalog)),
      petsProvider.overrideWith((ref) => Future.value(const PetsPayload(pets: _pets, max: 3))),
      ledgerProvider.overrideWith(
        () => _StubLedger(
          LedgerFeed(entries: [
            LedgerEntry(id: 1, delta: 240, balanceAfter: 1240, reason: 'order_earn', note: 'طلب #32579', createdAt: DateTime(2026, 9, 1)),
            LedgerEntry(id: 2, delta: -250, balanceAfter: 1000, reason: 'redeem', note: 'ترقية توصيل سريع', createdAt: DateTime(2026, 8, 28)),
            LedgerEntry(id: 3, delta: 100, balanceAfter: 1250, reason: 'profile_complete', createdAt: DateTime(2026, 8, 20)),
            LedgerEntry(id: 4, delta: 50, balanceAfter: 1150, reason: 'pet_added', note: 'أوريو', createdAt: DateTime(2026, 8, 20)),
          ]),
        ),
      ),
    ];

Future<void> _shoot(WidgetTester tester, Widget screen, String name, {double height = 2400, List<Override> overrides = const []}) async {
  tester.view.physicalSize = Size(393 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(screen, overrides: overrides));
  await tester.pump(const Duration(milliseconds: 900));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/family_$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('hub', (tester) async {
    await _shoot(tester, const FamilyHubScreen(), 'hub', height: 2500, overrides: _member());
  });

  testWidgets('rewards', (tester) async {
    await _shoot(tester, const RewardsScreen(), 'rewards', height: 1200, overrides: _member());
  });

  testWidgets('ledger', (tester) async {
    await _shoot(tester, const LedgerScreen(), 'ledger', height: 900, overrides: _member());
  });

  testWidgets('pets', (tester) async {
    await _shoot(tester, const PetsScreen(), 'pets', height: 700, overrides: _member());
  });

  testWidgets('pet profile', (tester) async {
    final care = PetCare(
      pet: _pets.first.copyWith(neutered: true),
      plan: const FeedingPlan(kcalDay: 246, stage: 'adult', dryGDay: 65, wetGDay: 270, mixedDryGDay: 35, mixedWetGDay: 140),
      latestKg: 4.2,
      weights: [
        WeightEntry(id: 1, kg: 3.8, on: DateTime(2026, 5, 1), source: 'profile'),
        WeightEntry(id: 2, kg: 3.9, on: DateTime(2026, 6, 1)),
        WeightEntry(id: 3, kg: 4.1, on: DateTime(2026, 7, 15)),
        WeightEntry(id: 4, kg: 4.2, on: DateTime(2026, 9, 5)),
      ],
      trend: const WeightTrend(fromKg: 3.8, toKg: 4.2, deltaKg: 0.4, deltaPct: 10.5, days: 127, direction: 'up', flag: 'gain'),
      reminders: const [
        CareReminder(pet: PetRef(id: 7, name: 'أوريو', species: PetSpecies.cat), kind: 'deworm', label: 'علاج الديدان', state: 'overdue', days: -3, intervalDays: 90, lastOn: null, products: [
          ProductCard(id: 17203, name: 'بيفار كومبوتيك قطرة لعلاج البراغيث والقراد والقمل للقطط', image: null, price: 45),
          ProductCard(id: 11083, name: 'بيفار بخاخ للتخلص من القراد للقطط والكلاب 50مل', image: null, price: 39),
        ]),
        CareReminder(pet: PetRef(id: 7, name: 'أوريو', species: PetSpecies.cat), kind: 'vaccine', label: 'التطعيم', state: 'soon', days: 5, intervalDays: 365),
        CareReminder(pet: PetRef(id: 7, name: 'أوريو', species: PetSpecies.cat), kind: 'flea_tick', label: 'البراغيث والقراد', state: 'ok', days: 22, intervalDays: 30),
        CareReminder(pet: PetRef(id: 7, name: 'أوريو', species: PetSpecies.cat), kind: 'grooming', label: 'التنظيف والتجميل', state: 'unset', intervalDays: 60),
        CareReminder(pet: PetRef(id: 7, name: 'أوريو', species: PetSpecies.cat), kind: 'checkup', label: 'الفحص الدوري', state: 'unset', intervalDays: 365),
      ],
      supply: _summary().supply.items,
    );
    await _shoot(
      tester,
      PetProfileScreen(petId: 7, initial: _pets.first),
      'pet_profile',
      height: 2100,
      overrides: [..._member(), petCareProvider.overrideWith((ref, id) => Future.value(care))],
    );
  });

  testWidgets('pet editor', (tester) async {
    await _shoot(tester, const PetEditorScreen(), 'pet_editor', height: 1000, overrides: _member());
  });

  testWidgets('home cards', (tester) async {
    final summary = _summary();
    final noPending = _summary(pending: false);
    await _shoot(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: FamilyCard(summary: null)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FamilyCard(summary: LoyaltySummary(paws: const PawsBalance(balance: 320), tier: summary.tier)),
            ),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: FamilyCard(summary: summary)),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: FamilyCard(summary: noPending)),
            const SizedBox(height: 20),
            const MissionsStrip(missions: _missions, awaitingDelivery: true),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FreeShippingBar(freeShipping: FreeShipping(min: 200, remaining: 80), freeDeliveryReason: 'reward'),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FreeShippingBar(freeShipping: FreeShipping(min: 200, remaining: 80), expressFreeReason: 'tier'),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FreeShippingBar(freeShipping: FreeShipping(min: 200, remaining: 80)),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ScratchCardView(card: ScratchCard(id: 88, order: LoyaltyOrderRef(id: 4001, number: '32579'), prize: ScratchPrize(kind: 'paws', paws: 50))),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ScratchCardView(card: ScratchCard(id: 89, state: 'revealed', prize: ScratchPrize(kind: 'paws', paws: 50))),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      'home_cards',
      height: 1900,
      overrides: _member(),
    );
  });
}
