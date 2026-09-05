import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The home card has four jobs and must never do two of them at once. These
/// lock the resolution order — a due reorder outranks a mission, a mission
/// outranks standing — and the fact that a control-group member never sees a
/// mission on the storefront.

class _RecordingEvents implements EventsBuffer {
  final List<ZbEvent> events = [];

  @override
  void track(ZbEvent event) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

late _RecordingEvents _events;

Widget _host(LoyaltySummary? summary, {HomeFeed? feed}) => ProviderScope(
      overrides: [eventsBufferProvider.overrideWithValue(_events)],
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 380,
                child: FamilyCard(summary: summary, feed: feed),
              ),
            ),
          ),
        ),
      ),
    );

Pet _pet() => const Pet(id: 7, name: 'مشمش', species: PetSpecies.cat);

LoyaltySummary _summary({
  List<Pet> pets = const [],
  List<Mission> missions = const [],
  bool holdout = false,
  int paws = 320,
}) =>
    LoyaltySummary(
      member: LoyaltyMember(holdout: holdout),
      paws: PawsBalance(balance: paws),
      tier: const TierInfo(
        key: 'star',
        name: 'مميّز',
        orders12m: 5,
        min: 4,
        next: NextTier(key: 'gold', name: 'ذهبي', min: 8, ordersNeeded: 3),
      ),
      missions: MissionsBlock(items: missions),
      pets: pets,
    );

const Mission _mission = Mission(
  id: 12,
  key: 'frequency',
  title: '3 طلبات هذا الشهر',
  target: 3,
  progress: 2,
);

HomeFeed _feedWithDue() => const HomeFeed(
      personal: PersonalSlot(
        kind: 'buyagain',
        title: 'اطلبها مجددًا',
        products: [ProductCard(id: 900, name: 'رويال كانين', price: 89)],
        hints: {900: ReorderHint(lastOrderedDays: 34, due: true)},
      ),
    );

void main() {
  setUp(() => _events = _RecordingEvents());

  test('the variant is resolved by usefulness, not by availability', () {
    expect(FamilyCard.variantOf(null, null), FamilyCardVariant.guest);
    expect(FamilyCard.variantOf(_summary(), null), FamilyCardVariant.noPet);

    final withPet = _summary(pets: [_pet()], missions: const [_mission]);
    // A reorder that is actually due beats an unfinished mission.
    expect(FamilyCard.variantOf(withPet, _feedWithDue()), FamilyCardVariant.due);
    expect(FamilyCard.variantOf(withPet, null), FamilyCardVariant.mission);
    expect(
      FamilyCard.variantOf(_summary(pets: [_pet()]), null),
      FamilyCardVariant.tier,
    );

    // A control-group member gets standing, never a mission.
    final holdout =
        _summary(pets: [_pet()], missions: const [_mission], holdout: true);
    expect(FamilyCard.variantOf(holdout, null), FamilyCardVariant.tier);
  });

  test('a feed with nothing due yields no due product', () {
    expect(FamilyCard.dueProduct(null), isNull);
    expect(FamilyCard.dueProduct(HomeFeed.empty), isNull);
    expect(
      FamilyCard.dueProduct(
        const HomeFeed(
          personal: PersonalSlot(
            kind: 'buyagain',
            products: [ProductCard(id: 1, name: 'طعام', price: 10)],
            hints: {1: ReorderHint(lastOrderedDays: 4)},
          ),
        ),
      ),
      isNull,
    );
    expect(FamilyCard.dueProduct(_feedWithDue())?.id, 900);
  });

  testWidgets('guest — an invitation, never a locked door', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('انضم إلى عائلة زوبوكسي'), findsOneWidget);
    expect(find.text('ابدأ الآن'), findsOneWidget);
    expect(find.text('مشمش'), findsNothing);
    expect(_events.events.single.payload?['variant'], 'guest');
  });

  testWidgets('signed in with no pet — the same ask, plus the balance',
      (tester) async {
    await tester.pumpWidget(_host(_summary(paws: 320)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('من هو صديقك؟'), findsOneWidget);
    expect(find.text('أضف حيوانك'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(_events.events.single.payload?['variant'], 'noPet');
  });

  testWidgets('a due reorder — the pet, the product and the button',
      (tester) async {
    await tester.pumpWidget(
      _host(_summary(pets: [_pet()], missions: const [_mission]),
          feed: _feedWithDue()),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('مشمش'), findsOneWidget);
    expect(find.text('حان وقت إعادة طلب رويال كانين'), findsOneWidget);
    expect(find.text('اطلب الآن'), findsOneWidget);
    // The mission is not also on the card.
    expect(find.text('3 طلبات هذا الشهر'), findsNothing);
    expect(_events.events.single.payload?['variant'], 'due');
  });

  testWidgets('a mission — its title and how close it is', (tester) async {
    await tester.pumpWidget(
      _host(_summary(pets: [_pet()], missions: const [_mission])),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('مشمش'), findsOneWidget);
    expect(find.text('3 طلبات هذا الشهر'), findsOneWidget);
    expect(find.text('2 من 3'), findsOneWidget);
    expect(_events.events.single.payload?['variant'], 'mission');
  });

  testWidgets('standing — the quiet fallback', (tester) async {
    await tester.pumpWidget(_host(_summary(pets: [_pet()], paws: 1240)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('مشمش'), findsOneWidget);
    expect(find.text('مميّز'), findsOneWidget);
    expect(find.text('1٬240'), findsOneWidget);
    expect(find.text('3 طلبات تفصلك عن ذهبي'), findsOneWidget);
    expect(_events.events.single.payload?['variant'], 'tier');
  });

  testWidgets('the card reports itself once, not once per frame',
      (tester) async {
    await tester.pumpWidget(_host(_summary(pets: [_pet()])));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_events.events.where((e) => e.type == ZbEvents.familyCard), hasLength(1));
  });
}
