import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is not part of flutter_riverpod's default surface in 3.x.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_repository.dart';
import 'package:zooboxi_app/features/loyalty/presentation/family_hub_screen.dart';
import 'package:zooboxi_app/features/loyalty/presentation/ledger_screen.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/mission_card.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/scratch_card_view.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/data/pets_repository.dart';
import 'package:zooboxi_app/features/pets/presentation/pets_screen.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The screens, in the two states that matter most: a guest who has no account
/// yet, and a member who does. A guest must never meet a 401 — the program's
/// front door is an invitation.

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

Widget _host(Widget screen, {List<Override> overrides = const []}) => ProviderScope(
      overrides: [
        eventsBufferProvider.overrideWithValue(_SilentEvents()),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        // Reduce Motion: the mascot's idle bob is an endless ticker, and a
        // screen test has no business waiting on decoration.
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: widget!,
        ),
        home: screen,
      ),
    );

const _mission = Mission(
  id: 12,
  key: 'frequency',
  title: '3 طلبات هذا الشهر',
  body: 'كل طلب يصلك يحتسب',
  target: 3,
  progress: 2,
  reward: MissionReward(paws: 300),
);

LoyaltySummary _summary({bool holdout = false}) => LoyaltySummary(
      member: LoyaltyMember(holdout: holdout, joinedAt: DateTime(2026, 3, 1)),
      paws: const PawsBalance(balance: 1240, pending: 120),
      tier: const TierInfo(
        key: 'star',
        name: 'مميّز',
        orders12m: 5,
        min: 4,
        next: NextTier(key: 'gold', name: 'ذهبي', min: 8, ordersNeeded: 3),
        perks: [
          TierPerk(key: 'free_min_150', text: 'الشحن المجاني من 150 ﷼', active: true),
          TierPerk(
            key: 'express_free_always',
            text: 'توصيل سريع مجاني دائمًا',
            fromTier: 'gold',
          ),
        ],
      ),
      missions: MissionsBlock(items: holdout ? const [] : const [_mission]),
      rewards: SummaryRewards(
        activeCount: 1,
        sealedScratch:
            holdout ? const [] : const [SealedScratch(id: 88, orderNumber: '32579')],
      ),
      pets: const [Pet(id: 7, name: 'مشمش', species: PetSpecies.cat)],
    );

void main() {
  testWidgets('a guest at /family is invited, not refused', (tester) async {
    await tester.pumpWidget(
      _host(
        const FamilyHubScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(false),
          loyaltySummaryProvider.overrideWith((ref) => Future.value(null)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('انضم إلى عائلة زوبوكسي'), findsOneWidget);
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(find.textContaining('401'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member sees standing, perks, missions and the sealed card',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _host(
        const FamilyHubScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          loyaltySummaryProvider.overrideWith((ref) => Future.value(_summary())),
          loyaltyRewardsProvider
              .overrideWith((ref) => Future.value(RewardsCatalog.empty)),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('مميّز'), findsWidgets);
    expect(find.text('3 طلبات تفصلك عن ذهبي'), findsOneWidget);
    expect(find.text('الشحن المجاني من 150 ﷼'), findsOneWidget);
    expect(find.text('من مستوى ذهبي'), findsOneWidget);
    expect(find.text('120 بصمة قيد التفعيل'), findsOneWidget);
    expect(find.byType(SealedScratchTile), findsOneWidget);
    expect(find.byType(MissionCard), findsOneWidget);
    expect(find.text('مشمش'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a holdout member keeps the wallet and loses the games',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _host(
        const FamilyHubScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          loyaltySummaryProvider
              .overrideWith((ref) => Future.value(_summary(holdout: true))),
          loyaltyRewardsProvider
              .overrideWith((ref) => Future.value(RewardsCatalog.empty)),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('مميّز'), findsWidgets);
    expect(find.text('1٬240'), findsWidgets);
    expect(find.byType(SealedScratchTile), findsNothing);
    expect(find.byType(MissionCard), findsNothing);
    expect(find.text('مهمات الشهر'), findsNothing);
  });

  testWidgets('the ledger reads as a statement, newest first', (tester) async {
    await tester.pumpWidget(
      _host(
        const LedgerScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          loyaltySummaryProvider.overrideWith((ref) => Future.value(_summary())),
          ledgerProvider.overrideWith(
            () => _StubLedger(
              LedgerFeed(
                entries: [
                  LedgerEntry(
                    id: 1,
                    delta: 240,
                    balanceAfter: 1240,
                    reason: 'order_earn',
                    createdAt: DateTime(2026, 9, 1),
                  ),
                  const LedgerEntry(
                    id: 2,
                    delta: -400,
                    balanceAfter: 840,
                    reason: 'redeem',
                    note: 'توصيل مجاني',
                  ),
                ],
                hasMore: true,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('طلب مسلَّم'), findsOneWidget);
    expect(find.text('استبدال'), findsOneWidget);
    expect(find.text('+240'), findsOneWidget);
    expect(find.text('−400'), findsOneWidget);
    expect(find.text('الرصيد 840'), findsOneWidget);
    expect(find.text('عرض المزيد'), findsOneWidget);
  });

  testWidgets('an empty ledger explains itself instead of showing zero rows',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const LedgerScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          loyaltySummaryProvider.overrideWith((ref) => Future.value(null)),
          ledgerProvider.overrideWith(() => _StubLedger(LedgerFeed.empty)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('السجل فارغ'), findsOneWidget);
    expect(find.text('أول طلب يصلك يفتح السجل'), findsOneWidget);
  });

  testWidgets('an empty family offers the one thing worth doing',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const PetsScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          petsProvider.overrideWith((ref) => Future.value(PetsPayload.empty)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا حيوانات بعد'), findsOneWidget);
    expect(find.text('أضف حيوانًا'), findsOneWidget);
  });

  testWidgets('a full family says so rather than offering a fourth slot',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const PetsScreen(),
        overrides: [
          isAuthenticatedProvider.overrideWithValue(true),
          petsProvider.overrideWith(
            (ref) => Future.value(
              const PetsPayload(
                max: 3,
                pets: [
                  Pet(id: 1, name: 'مشمش', species: PetSpecies.cat),
                  Pet(id: 2, name: 'ريم', species: PetSpecies.dog),
                  Pet(id: 3, name: 'زقزق', species: PetSpecies.bird),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('مشمش'), findsOneWidget);
    expect(find.text('ريم'), findsOneWidget);
    expect(find.text('زقزق'), findsOneWidget);
    expect(find.text('أضف حيوانًا'), findsNothing);
    expect(find.text('يمكنك إضافة 3 حيوانات'), findsOneWidget);
  });
}
