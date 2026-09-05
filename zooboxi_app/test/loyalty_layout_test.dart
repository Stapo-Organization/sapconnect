import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/presentation/widgets/gift_cart_line.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/missions_strip.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/grant_card.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/mission_card.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/reward_card.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/scratch_card_view.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/tier_card.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/presentation/widgets/pet_card.dart';
import 'package:zooboxi_app/features/pets/presentation/widgets/species_avatar.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// Every loyalty surface, in both languages, at the text size a customer with
/// tired eyes actually uses.
///
/// Arabic tier names, five-figure balances and "توصيل سريع مجاني" are all
/// longer than the English the layouts were sketched with — this is the test
/// that keeps that from becoming a yellow-and-black bar on the owner's phone.

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}
  @override
  Future<void> flush() async {}
  @override
  void dispose() {}
}

Widget _host(Widget child, {required Locale locale, required double scale}) =>
    ProviderScope(
      overrides: [eventsBufferProvider.overrideWithValue(_SilentEvents())],
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(locale),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: widget!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

const _mission = Mission(
  id: 1,
  title: 'جرّب الأكل الرطب لمشمش من ماركة لم تشترها من قبل',
  body: 'اختر أي صنف من الماركات المقترحة خلال هذا الشهر',
  target: 3,
  progress: 1,
  reward: MissionReward(paws: 300),
);

const _tier = TierInfo(
  key: 'star',
  name: 'مميّز جدًا',
  orders12m: 5,
  min: 4,
  next: NextTier(key: 'gold', name: 'ذهبي', min: 8, ordersNeeded: 3),
  perks: [
    TierPerk(key: 'free_min_150', text: 'الشحن المجاني من 150 ﷼', active: true),
    TierPerk(
      key: 'express_free_always',
      text: 'توصيل سريع مجاني دائمًا داخل نطاق المستودع',
      fromTier: 'gold',
    ),
    TierPerk(
      key: 'free_delivery_always',
      text: 'توصيل مجاني بلا حد أدنى',
      fromTier: 'amb',
    ),
  ],
);

const _express = Reward(
  id: 3,
  kind: 'express_free',
  title: 'ترقية توصيل سريع مجاني على طلبك القادم',
  description: 'تصفّر رسم التوصيل السريع على الطلب التالي',
  pawsCost: 250,
  valueSar: 25,
  validityDays: 14,
);

const _gift = CartItem(
  key: 'gift-1',
  productId: 55,
  name: '🎁 هدية · لعبة قطط بريش ملوّن',
  qty: 1,
  isGift: true,
  grantId: 123,
  lockedQty: true,
);

LoyaltySummary _summary({List<Mission> missions = const [_mission]}) =>
    LoyaltySummary(
      paws: const PawsBalance(balance: 12400, pending: 350),
      tier: _tier,
      missions: MissionsBlock(items: missions),
      pets: const [Pet(id: 1, name: 'مشمش الصغير', species: PetSpecies.cat)],
    );

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    for (final scale in const [1.0, 1.3]) {
      final tag = '${locale.languageCode} @ ${scale}x';

      testWidgets('the loyalty cards fit — $tag', (tester) async {
        tester.view.physicalSize = const Size(393 * 3, 2600 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _host(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const TierCard(
                    tier: _tier,
                    paws: PawsBalance(balance: 12400, pending: 350),
                  ),
                  const SizedBox(height: 12),
                  const MissionCard(mission: _mission),
                  const SizedBox(height: 12),
                  const RewardCard(reward: _express, balance: 100),
                  const SizedBox(height: 12),
                  const GrantCard(
                    grant: Grant(
                      id: 5,
                      reward: _express,
                      state: 'pending',
                      activatesOnOrder:
                          LoyaltyOrderRef(id: 4001, number: '32579'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const PetCard(
                    pet: Pet(
                      id: 1,
                      name: 'مشمش الصغير',
                      species: PetSpecies.cat,
                      breed: 'شيرازي أبيض',
                      ageLabel: 'سنتان و3 أشهر',
                      weightKg: 4.2,
                      birthdayInDays: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const GiftCartLineView(item: _gift),
                  const SizedBox(height: 12),
                  SealedScratchTile(orderNumber: '32579', onTap: () {}),
                ],
              ),
            ),
            locale: locale,
            scale: scale,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the home surfaces fit — $tag', (tester) async {
        tester.view.physicalSize = const Size(393 * 3, 1800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _host(
            Column(
              children: [
                const MissionsStrip(missions: [_mission, _mission]),
                const SizedBox(height: 12),
                for (final summary in [null, _summary(), _summary(missions: const [])])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: FamilyCard(summary: summary),
                  ),
              ],
            ),
            locale: locale,
            scale: scale,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every species has a portrait and none of them throws',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Wrap(
          children: [
            for (final species in PetSpecies.values) ...[
              SpeciesAvatar(species: species, size: 72),
              SpeciesAvatar(species: species, size: 24),
            ],
          ],
        ),
        locale: const Locale('ar'),
        scale: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(SpeciesAvatar),
      findsNWidgets(PetSpecies.values.length * 2),
    );
    expect(tester.takeException(), isNull);
  });
}
