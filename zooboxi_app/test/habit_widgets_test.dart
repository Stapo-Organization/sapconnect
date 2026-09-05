import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/moment_cards.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/subscription_card.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/supply_card.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The Phase 2 cards at a phone width, in both languages, at the large text
/// scale — the layouts that overflow are the ones a customer with big fonts
/// meets first.

class _SilentEvents implements EventsBuffer {
  @override
  void track(ZbEvent event) {}

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

Widget _host(Widget child, {String locale = 'ar', double scale = 1.0}) => ProviderScope(
      overrides: [eventsBufferProvider.overrideWithValue(_SilentEvents())],
      child: MaterialApp(
        locale: Locale(locale),
        theme: AppTheme.light(Locale(locale)),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(child: SizedBox(width: 358, child: child)),
            ),
          ),
        ),
      ),
    );

const _product = ProductCard(id: 501, name: 'رويال كانين قطط بالغة دجاج 2 كجم', image: null, price: 120);

const _item = SupplyItem(
  product: _product,
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
);

const _sub = Subscription(
  id: 12,
  product: _product,
  qty: 2,
  intervalDays: 30,
  daysUntil: 2,
  deliveries: 2,
  nextGiftIn: 1,
  pet: PetRef(id: 7, name: 'مشمش', species: PetSpecies.cat),
);

void main() {
  for (final locale in ['ar', 'en']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('the gauge card fits — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          SupplyGaugeCard(item: _item, onOrder: () {}, onOut: () {}, onSnooze: () {}, onSubscribe: () {}),
          locale: locale,
          scale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(SupplyRing), findsOneWidget);
      });

      testWidgets('the subscription card fits — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          SubscriptionCard(sub: _sub, onOrderNow: () {}, onSkip: () {}, onEdit: () {}),
          locale: locale,
          scale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('the referral and stamp cards fit — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          Column(
            children: [
              ReferralCard(
                referral: const ReferralSummary(code: 'ZBUCNBN', url: 'https://x/?ref=ZBUCNBN'),
                onShare: () {},
              ),
              const SizedBox(height: 12),
              const StampCardView(
                card: StampCard(programId: 3, title: 'بطاقة رويال كانين', brandName: 'Royal Canin', unitsRequired: 6, minPackKg: 1.5, units: 4, remaining: 2),
              ),
              const SizedBox(height: 12),
              const TierRiskLine(
                risk: TierRisk(inDays: 12, ordersDropping: 1, wouldDropTo: 'friend', wouldDropToName: 'صديق'),
                accent: Colors.teal,
              ),
            ],
          ),
          locale: locale,
          scale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the home card shows the gauge line with the order button', (tester) async {
    const summary = LoyaltySummary(
      pets: [Pet(id: 7, name: 'مشمش', species: PetSpecies.cat)],
      supply: SupplyBlock(items: [_item], dueCount: 1, total: 1),
    );
    await tester.pumpWidget(_host(const FamilyCard(summary: summary)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(FamilyCard.variantOf(summary, null), FamilyCardVariant.supply);
    expect(find.text('اطلب الآن'), findsOneWidget);
    expect(find.byType(SupplyRing), findsOneWidget);
  });

  testWidgets('the home card shows the subscription line with order and skip', (tester) async {
    const summary = LoyaltySummary(
      pets: [Pet(id: 7, name: 'مشمش', species: PetSpecies.cat)],
      subscriptions: SubscriptionsBlock(active: 1, next: _sub),
    );
    await tester.pumpWidget(_host(const FamilyCard(summary: summary)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(FamilyCard.variantOf(summary, null), FamilyCardVariant.subscription);
    expect(find.text('تخطَّ'), findsOneWidget);
  });

  testWidgets('the birthday card offers the gift when it is claimable', (tester) async {
    const grant = Grant(
      id: 71,
      reward: Reward(id: 5, kind: 'gift_product', title: 'هدية', titleEn: 'Gift', description: ''),
      state: 'active',
    );
    const moment = BirthdayMoment(pet: Pet(id: 7, name: 'مشمش', species: PetSpecies.cat), days: 3, grant: grant);
    await tester.pumpWidget(_host(BirthdayCard(moment: moment, onClaim: () {})));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('أضف الهدية للسلة'), findsOneWidget);
  });
}
