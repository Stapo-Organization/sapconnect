import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/family_card.dart';
import 'package:zooboxi_app/features/loyalty/data/loyalty_models.dart';
import 'package:zooboxi_app/features/pets/data/care_models.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';

/// The `/pets/{id}/care` payload and the summary's `care` block, parsed the
/// way the store actually sends them (a real prod response, trimmed).

const _payload = {
  'pet': {
    'id': 1,
    'name': 'اوريو',
    'species': 'cat',
    'breed': 'هيمالايا',
    'sex': 'm',
    'weight_kg': 4,
    'birth_date': '2025-10-21',
    'age_label': '10 أشهر',
    'neutered': false,
    'is_complete': true,
    'birthday_in_days': 46,
    'activity': '',
    'body_condition': '',
    'feed_g_day': null,
    'food_kcal': null,
    'plan_ok': true,
  },
  'plan': {
    'kcal_day': 396,
    'rer': 198,
    'factor': 2,
    'stage': 'junior',
    'dry_g_day': 105,
    'wet_g_day': 440,
    'mixed': {'dry_g_day': 55, 'wet_g_day': 220},
    'dry_kcal_100g': 375,
    'wet_kcal_100g': 90,
    'override_g_day': null,
    'effective_g_day': 105,
    'notes': [],
  },
  'weight': {
    'latest_kg': 4,
    'entries': [
      {'id': 1, 'kg': 3.6, 'on': '2026-06-01', 'source': 'profile'},
      {'id': 2, 'kg': 4, 'on': '2026-09-05', 'source': 'log'},
    ],
    'trend': {'from_kg': 3.6, 'to_kg': 4, 'delta_kg': 0.4, 'delta_pct': 11.1, 'days': 96, 'direction': 'up', 'flag': 'gain'},
  },
  'reminders': [
    {
      'pet': {'id': 1, 'name': 'اوريو', 'species': 'cat'},
      'kind': 'vaccine',
      'label': 'التطعيم',
      'state': 'soon',
      'days': 5,
      'interval_days': 365,
      'last_on': '2025-09-10',
      'next_on': '2026-09-10',
      'enabled': true,
      'done_count': 0,
      'products': [],
    },
    {
      'pet': {'id': 1, 'name': 'اوريو', 'species': 'cat'},
      'kind': 'deworm',
      'label': 'علاج الديدان',
      'state': 'overdue',
      'days': -3,
      'interval_days': 90,
      'last_on': '2026-06-03',
      'next_on': '2026-09-02',
      'enabled': true,
      'done_count': 2,
      'products': [
        {'id': 17203, 'name': 'بيفار فيبروتيك للقطط', 'image': null, 'price': 45},
      ],
    },
    {
      'pet': {'id': 1, 'name': 'اوريو', 'species': 'cat'},
      'kind': 'checkup',
      'label': 'الفحص الدوري',
      'state': 'unset',
      'days': null,
      'interval_days': 365,
      'last_on': null,
      'next_on': null,
      'enabled': true,
      'done_count': 0,
      'products': [],
    },
  ],
  'supply': [],
  'kinds': ['vaccine', 'deworm', 'flea_tick', 'grooming', 'checkup'],
  'paws_earned': 50,
};

void main() {
  group('PetCare', () {
    test('parses the plan, the log, the trend and the reminders', () {
      final care = PetCare.fromJson(Map<String, dynamic>.from(_payload));
      expect(care.pet.planOk, isTrue);
      expect(care.pet.species, PetSpecies.cat);
      expect(care.plan, isNotNull);
      expect(care.plan!.stage, 'junior');
      expect(care.plan!.dryGDay, 105);
      expect(care.plan!.effectiveGDay, 105);
      expect(care.plan!.hasOverride, isFalse);
      expect(care.latestKg, 4);
      expect(care.weights, hasLength(2));
      expect(care.weights.first.source, 'profile');
      expect(care.trend!.flag, 'gain');
      expect(care.trend!.isFlagged, isTrue);
      expect(care.reminders, hasLength(3));
      expect(care.reminders[0].needsAttention, isTrue);
      expect(care.reminders[0].isDueNow, isFalse);
      expect(care.reminders[1].isDueNow, isTrue);
      expect(care.reminders[1].products.single.id, 17203);
      expect(care.reminders[2].isSet, isFalse);
      expect(care.dueCount, 2);
      expect(care.pawsEarned, 50);
    });

    test('an override wins over the plan', () {
      final json = Map<String, dynamic>.from(_payload);
      json['plan'] = {...(_payload['plan']! as Map), 'override_g_day': 50, 'effective_g_day': 50};
      final care = PetCare.fromJson(json);
      expect(care.plan!.hasOverride, isTrue);
      expect(care.plan!.effectiveGDay, 50);
    });

    test('a pet without a plan parses to null, never to zeros', () {
      final json = Map<String, dynamic>.from(_payload);
      json['plan'] = null;
      json['weight'] = {'latest_kg': null, 'entries': [], 'trend': null};
      final care = PetCare.fromJson(json);
      expect(care.plan, isNull);
      expect(care.latestKg, isNull);
      expect(care.trend, isNull);
      expect(care.weights, isEmpty);
    });
  });

  group('CareBlock in the summary', () {
    LoyaltySummary summary(List<Map<String, Object?>> due) => LoyaltySummary.fromJson({
          'pets': [
            {'id': 1, 'name': 'اوريو', 'species': 'cat'},
          ],
          'care': {'enabled': true, 'due': due, 'due_count': due.length, 'weigh_in': true},
        });

    test('the home card wears the care face only for today or overdue', () {
      final soon = summary([
        (_payload['reminders']! as List)[0] as Map<String, Object?>,
      ]);
      expect(soon.care.due, hasLength(1));
      expect(soon.care.dueNow, isNull);
      expect(FamilyCard.variantOf(soon, null), isNot(FamilyCardVariant.care));

      final overdue = summary([
        (_payload['reminders']! as List)[0] as Map<String, Object?>,
        (_payload['reminders']! as List)[1] as Map<String, Object?>,
      ]);
      expect(overdue.care.dueNow!.kind, 'deworm');
      expect(overdue.care.weighIn, isTrue);
      expect(FamilyCard.variantOf(overdue, null), FamilyCardVariant.care);
    });

    test('a summary without the block stays empty and harmless', () {
      final s = LoyaltySummary.fromJson({'pets': []});
      expect(s.care.due, isEmpty);
      expect(s.care.dueNow, isNull);
      expect(s.care.weighIn, isFalse);
    });
  });
}
