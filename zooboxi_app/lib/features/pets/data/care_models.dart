import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import '../../catalog/data/product_models.dart';
import '../../loyalty/data/loyalty_models.dart';
import 'pet_models.dart';

/// «الرفيق» — what the store knows about caring for one animal.
///
/// Every number here is the server's. The plan, the trend and the reminder
/// states are computed where the gauge lives, so the profile and the food
/// countdown can never tell the customer two different stories.

/// The feeding plan: energy per day, and what that is in food.
@immutable
class FeedingPlan {
  const FeedingPlan({
    required this.kcalDay,
    required this.stage,
    required this.dryGDay,
    required this.wetGDay,
    required this.mixedDryGDay,
    required this.mixedWetGDay,
    this.factor = 1,
    this.dryKcal100g = 375,
    this.wetKcal100g = 90,
    this.overrideGDay,
    this.notes = const [],
  });

  final int kcalDay;

  /// `kitten` | `puppy` | `junior` | `adult` | `senior`.
  final String stage;
  final double factor;
  final double dryGDay;
  final double wetGDay;
  final double mixedDryGDay;
  final double mixedWetGDay;
  final int dryKcal100g;
  final int wetKcal100g;

  /// The customer's own grams/day, when they set one.
  final double? overrideGDay;
  final List<String> notes;

  /// What the gauge actually counts with.
  double get effectiveGDay => overrideGDay ?? dryGDay;
  bool get hasOverride => overrideGDay != null;

  static FeedingPlan? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    final mixed = asMap(map['mixed']);
    return FeedingPlan(
      kcalDay: asInt(map['kcal_day']),
      stage: asString(map['stage'], fallback: 'adult'),
      factor: asDouble(map['factor'], fallback: 1),
      dryGDay: asDouble(map['dry_g_day']),
      wetGDay: asDouble(map['wet_g_day']),
      mixedDryGDay: asDouble(mixed['dry_g_day']),
      mixedWetGDay: asDouble(mixed['wet_g_day']),
      dryKcal100g: asInt(map['dry_kcal_100g'], fallback: 375),
      wetKcal100g: asInt(map['wet_kcal_100g'], fallback: 90),
      overrideGDay: asDoubleOrNull(map['override_g_day']),
      notes: (map['notes'] is List ? map['notes'] as List : const []).map((e) => e.toString()).toList(),
    );
  }
}

/// One reading on the scale.
@immutable
class WeightEntry {
  const WeightEntry({required this.id, required this.kg, required this.on, this.source = 'log'});

  final int id;
  final double kg;
  final DateTime on;

  /// `log` (the customer typed it here) or `profile` (echoed from an edit).
  final String source;

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: asInt(json['id']),
        kg: asDouble(json['kg']),
        on: asDate(json['on']) ?? DateTime.now(),
        source: asString(json['source'], fallback: 'log'),
      );

  static List<WeightEntry> listFrom(dynamic value) => asMapList(value).map(WeightEntry.fromJson).toList();
}

/// Latest reading against one at least two months older.
@immutable
class WeightTrend {
  const WeightTrend({
    required this.fromKg,
    required this.toKg,
    required this.deltaKg,
    required this.deltaPct,
    required this.days,
    this.direction = 'flat',
    this.flag = 'none',
  });

  final double fromKg;
  final double toKg;
  final double deltaKg;
  final double deltaPct;
  final int days;

  /// `up` | `down` | `flat`.
  final String direction;

  /// `gain` | `loss` | `none` — ±10 % is worth a sentence, never a diagnosis.
  final String flag;

  bool get isFlagged => flag != 'none';

  static WeightTrend? maybe(dynamic value) {
    if (value is! Map) return null;
    final map = asMap(value);
    return WeightTrend(
      fromKg: asDouble(map['from_kg']),
      toKg: asDouble(map['to_kg']),
      deltaKg: asDouble(map['delta_kg']),
      deltaPct: asDouble(map['delta_pct']),
      days: asInt(map['days']),
      direction: asString(map['direction'], fallback: 'flat'),
      flag: asString(map['flag'], fallback: 'none'),
    );
  }
}

/// One care reminder for one pet — stored or not yet set.
@immutable
class CareReminder {
  const CareReminder({
    required this.pet,
    required this.kind,
    required this.label,
    this.state = 'unset',
    this.days,
    this.intervalDays = 90,
    this.lastOn,
    this.nextOn,
    this.enabled = true,
    this.doneCount = 0,
    this.products = const [],
  });

  final PetRef pet;

  /// `vaccine` | `deworm` | `flea_tick` | `grooming` | `checkup`.
  final String kind;

  /// The server's localized name for the kind.
  final String label;

  /// `unset` | `off` | `ok` | `soon` | `due` | `overdue`.
  final String state;

  /// Days until the next date (negative when overdue), null when unset.
  final int? days;
  final int intervalDays;
  final DateTime? lastOn;
  final DateTime? nextOn;
  final bool enabled;
  final int doneCount;

  /// Up to three products that answer this reminder.
  final List<ProductCard> products;

  bool get isSet => state != 'unset';
  bool get isOff => state == 'off';
  bool get needsAttention => state == 'soon' || state == 'due' || state == 'overdue';
  bool get isDueNow => state == 'due' || state == 'overdue';

  factory CareReminder.fromJson(Map<String, dynamic> json) => CareReminder(
        pet: PetRef.maybe(json['pet']) ?? const PetRef(id: 0, name: '', species: PetSpecies.other),
        kind: asString(json['kind']),
        label: asString(json['label']),
        state: asString(json['state'], fallback: 'unset'),
        days: asIntOrNull(json['days']),
        intervalDays: asInt(json['interval_days'], fallback: 90),
        lastOn: asDate(json['last_on']),
        nextOn: asDate(json['next_on']),
        enabled: json['enabled'] == null ? true : asBool(json['enabled']),
        doneCount: asInt(json['done_count']),
        products: ProductCard.listFrom(json['products']),
      );

  static List<CareReminder> listFrom(dynamic value) => asMapList(value).map(CareReminder.fromJson).toList();
}

/// `GET /pets/{id}/care`.
@immutable
class PetCare {
  const PetCare({
    required this.pet,
    this.plan,
    this.latestKg,
    this.weights = const [],
    this.trend,
    this.reminders = const [],
    this.supply = const [],
    this.pawsEarned = 0,
  });

  final Pet pet;
  final FeedingPlan? plan;
  final double? latestKg;

  /// Oldest first.
  final List<WeightEntry> weights;
  final WeightTrend? trend;
  final List<CareReminder> reminders;

  /// The gauge lines that feed this pet.
  final List<SupplyItem> supply;

  /// What the write that produced this payload paid (a weigh-in mission).
  final int pawsEarned;

  int get dueCount => reminders.where((r) => r.needsAttention).length;

  factory PetCare.fromJson(Map<String, dynamic> json) {
    final weight = asMap(json['weight']);
    return PetCare(
      pet: Pet.fromJson(asMap(json['pet'])),
      plan: FeedingPlan.maybe(json['plan']),
      latestKg: asDoubleOrNull(weight['latest_kg']),
      weights: WeightEntry.listFrom(weight['entries']),
      trend: WeightTrend.maybe(weight['trend']),
      reminders: CareReminder.listFrom(json['reminders']),
      supply: SupplyItem.listFrom(json['supply']),
      pawsEarned: asInt(json['paws_earned']),
    );
  }
}

/// The summary's `care` block: what needs attention across the family.
@immutable
class CareBlock {
  const CareBlock({this.enabled = true, this.due = const [], this.dueCount = 0, this.weighIn = false});

  final bool enabled;

  /// The nearest reminders (soon, due, overdue), soonest first.
  final List<CareReminder> due;
  final int dueCount;

  /// The monthly weigh-in mission is open.
  final bool weighIn;

  static const CareBlock empty = CareBlock();

  /// The one reminder worth the storefront card: today or overdue.
  CareReminder? get dueNow {
    for (final r in due) {
      if (r.isDueNow) return r;
    }
    return null;
  }

  factory CareBlock.fromJson(Map<String, dynamic> json) => CareBlock(
        enabled: json['enabled'] == null ? true : asBool(json['enabled']),
        due: CareReminder.listFrom(json['due']),
        dueCount: asInt(json['due_count']),
        weighIn: asBool(json['weigh_in']),
      );
}
