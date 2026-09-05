import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/analytics/events_buffer.dart';
import 'package:zooboxi_app/features/catalog/data/product_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/care_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/presentation/widgets/care_widgets.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The care cards at a phone width, both languages, large type — and the
/// home card's care face.

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

const _pet = Pet(id: 7, name: 'مشمش', species: PetSpecies.cat, weightKg: 4.2, birthDate: null, isComplete: false, planOk: true);
const _ref = PetRef(id: 7, name: 'مشمش', species: PetSpecies.cat);

const _plan = FeedingPlan(
  kcalDay: 246,
  stage: 'adult',
  dryGDay: 65,
  wetGDay: 270,
  mixedDryGDay: 35,
  mixedWetGDay: 140,
  notes: ['هذه كمية لخفض الوزن بلطف.'],
);

final _care = PetCare(
  pet: _pet,
  plan: _plan,
  latestKg: 4.2,
  weights: [
    WeightEntry(id: 1, kg: 3.8, on: DateTime(2026, 5, 1)),
    WeightEntry(id: 2, kg: 3.9, on: DateTime(2026, 6, 1)),
    WeightEntry(id: 3, kg: 4.1, on: DateTime(2026, 7, 15)),
    WeightEntry(id: 4, kg: 4.2, on: DateTime(2026, 9, 5)),
  ],
  trend: const WeightTrend(fromKg: 3.8, toKg: 4.2, deltaKg: 0.4, deltaPct: 10.5, days: 127, direction: 'up', flag: 'gain'),
  reminders: const [
    CareReminder(pet: _ref, kind: 'deworm', label: 'علاج الديدان', state: 'overdue', days: -3, intervalDays: 90, products: [
      ProductCard(id: 1, name: 'بيفار كومبوتيك قطرة لعلاج البراغيث والقراد للقطط', image: null, price: 45),
      ProductCard(id: 2, name: 'بخاخ للتخلص من القراد', image: null, price: 39),
    ]),
    CareReminder(pet: _ref, kind: 'vaccine', label: 'التطعيم', state: 'soon', days: 5, intervalDays: 365),
    CareReminder(pet: _ref, kind: 'checkup', label: 'الفحص الدوري', state: 'unset', intervalDays: 365),
  ],
);

void main() {
  for (final locale in ['ar', 'en']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('the feeding plan card fits — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          FeedingPlanCard(pet: _pet, plan: _plan, onActivity: (_) {}, onCondition: (_) {}, onOverride: () {}),
          locale: locale,
          scale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CareSegments), findsNWidgets(2));
      });

      testWidgets('the weight card fits — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          WeightCard(pet: _pet, care: _care, missionPaws: 50, onLog: () {}, onDelete: (_) {}),
          locale: locale,
          scale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('the reminder rows fit — $locale @ ${scale}x', (tester) async {
        await tester.pumpWidget(_host(
          Column(
            children: [
              for (final r in _care.reminders) CareReminderRow(reminder: r, onDone: () {}, onEdit: () {}, onProduct: (_) {}),
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

  testWidgets('a pet without a weight is asked for one, not shown zeros', (tester) async {
    await tester.pumpWidget(_host(FeedingPlanCard(pet: _pet.copyWith(clearWeight: true), plan: null, onAddWeight: () {})));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('أضف الوزن'), findsOneWidget);
    expect(find.byType(CareSegments), findsNothing);
  });

  testWidgets('a bird gets the quiet line, no calculator', (tester) async {
    await tester.pumpWidget(_host(const FeedingPlanCard(pet: Pet(id: 9, name: 'كيوي', species: PetSpecies.bird), plan: null)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CareSegments), findsNothing);
  });

  testWidgets('the home card shows the overdue reminder with «تم»', (tester) async {
    const summary = LoyaltySummary(
      pets: [Pet(id: 7, name: 'مشمش', species: PetSpecies.cat)],
      care: CareBlock(due: [
        CareReminder(pet: _ref, kind: 'deworm', label: 'علاج الديدان', state: 'overdue', days: -3, intervalDays: 90),
      ], dueCount: 1),
    );
    await tester.pumpWidget(_host(const FamilyCard(summary: summary)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(FamilyCard.variantOf(summary, null), FamilyCardVariant.care);
    expect(find.text('تم'), findsOneWidget);
  });

  test('state and interval labels', () {
    final l = lookupL(const Locale('ar'));
    expect(careStateLabel(l, const CareReminder(pet: _ref, kind: 'vaccine', label: 'x', state: 'due')), 'اليوم');
    expect(careStateLabel(l, const CareReminder(pet: _ref, kind: 'vaccine', label: 'x', state: 'overdue', days: -1)), 'تأخر يومًا');
    expect(careStateLabel(l, const CareReminder(pet: _ref, kind: 'vaccine', label: 'x', state: 'unset')), 'غير مضبوط');
    expect(careIntervalLabel(l, 90), 'كل 3 أشهر');
    expect(careIntervalLabel(l, 45), 'كل 45 يومًا');
    expect(careMarkOf('flea_tick').name, 'bug');
  });
}
