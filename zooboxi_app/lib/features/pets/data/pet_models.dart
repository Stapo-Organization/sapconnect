import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// The seven species the store's profile accepts. The key is the wire value —
/// anything the server adds later lands on [other] rather than breaking a
/// screen, which is the honest fallback for an avatar we cannot draw yet.
enum PetSpecies {
  cat('cat'),
  dog('dog'),
  bird('bird'),
  fish('fish'),
  small('small'),
  reptile('reptile'),
  other('other');

  const PetSpecies(this.key);

  final String key;

  static PetSpecies fromKey(String? value) {
    final key = (value ?? '').trim().toLowerCase();
    for (final species in PetSpecies.values) {
      if (species.key == key) return species;
    }
    return PetSpecies.other;
  }
}

/// One animal in «عائلتي».
///
/// `age_label` and `birthday_in_days` are the server's — it owns the calendar
/// the reminders run on, and a locally computed age would drift from the one
/// the push notification says.
@immutable
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed = '',
    this.sex = '',
    this.weightKg,
    this.birthDate,
    this.ageLabel,
    this.neutered,
    this.avatar = '',
    this.photoUrl,
    this.isComplete = false,
    this.birthdayInDays,
    this.activity = '',
    this.bodyCondition = '',
    this.feedGDay,
    this.foodKcal,
    this.planOk = false,
  });

  final int id;
  final String name;
  final PetSpecies species;
  final String breed;

  /// `m`, `f`, or empty for "not said".
  final String sex;
  final double? weightKg;
  final DateTime? birthDate;

  /// Pre-composed by the server: «سنتان و3 أشهر» / "2y 3m".
  final String? ageLabel;
  final bool? neutered;

  /// Key of a drawn avatar the customer picked; empty means "use the species".
  final String avatar;
  final String? photoUrl;

  /// Weight *and* birth date are on file — the two fields the 100-paw profile
  /// bonus and the food counter both need.
  final bool isComplete;

  /// Days until the next birthday, or null when there is no birth date.
  final int? birthdayInDays;

  /// `low` | `normal` | `high`, or empty when not said — a feeding-plan input.
  final String activity;

  /// `under` | `ideal` | `over`, or empty when not said.
  final String bodyCondition;

  /// The customer's own "I feed them N grams a day" — wins over the plan.
  final double? feedGDay;

  /// kcal per 100 g of their dry food, when they typed it off the bag.
  final int? foodKcal;

  /// The server can compute a feeding plan: a cat or dog with a weight.
  final bool planOk;

  /// True once this pet exists server-side.
  bool get isSaved => id > 0;

  bool get isBirthdaySoon {
    final days = birthdayInDays;
    return days != null && days >= 0 && days <= 7;
  }

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: asInt(json['id']),
        name: asString(json['name']),
        species: PetSpecies.fromKey(asStringOrNull(json['species'])),
        breed: asString(json['breed']),
        sex: asString(json['sex']),
        weightKg: asDoubleOrNull(json['weight_kg']),
        birthDate: asDate(json['birth_date']),
        ageLabel: asStringOrNull(json['age_label']),
        neutered: json['neutered'] == null ? null : asBool(json['neutered']),
        avatar: asString(json['avatar']),
        photoUrl: asStringOrNull(json['photo_url']),
        isComplete: asBool(json['is_complete']),
        birthdayInDays: asIntOrNull(json['birthday_in_days']),
        activity: asString(json['activity']),
        bodyCondition: asString(json['body_condition']),
        feedGDay: asDoubleOrNull(json['feed_g_day']),
        foodKcal: asIntOrNull(json['food_kcal']),
        planOk: asBool(json['plan_ok']),
      );

  /// The write shape. Optional fields ride along only when they have a value,
  /// so an edit that only renames a pet can't blank its weight.
  Map<String, dynamic> toJson() => {
        'name': name,
        'species': species.key,
        if (breed.isNotEmpty) 'breed': breed,
        if (sex.isNotEmpty) 'sex': sex,
        'weight_kg': ?weightKg,
        if (birthDate != null) 'birth_date': _isoDate(birthDate!),
        'neutered': ?neutered,
        if (avatar.isNotEmpty) 'avatar': avatar,
      };

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    String? sex,
    double? weightKg,
    DateTime? birthDate,
    bool? neutered,
    String? avatar,
    bool clearWeight = false,
    bool clearBirthDate = false,
  }) =>
      Pet(
        id: id,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        sex: sex ?? this.sex,
        weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
        ageLabel: ageLabel,
        neutered: neutered ?? this.neutered,
        avatar: avatar ?? this.avatar,
        photoUrl: photoUrl,
        isComplete: isComplete,
        birthdayInDays: birthdayInDays,
        activity: activity,
        bodyCondition: bodyCondition,
        feedGDay: feedGDay,
        foodKcal: foodKcal,
        planOk: planOk,
      );

  static List<Pet> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['pets'];
    return asMapList(raw).map(Pet.fromJson).toList();
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// `GET /pets` — the list plus the ceiling the editor has to respect.
@immutable
class PetsPayload {
  const PetsPayload({this.pets = const [], this.max = 3});

  final List<Pet> pets;
  final int max;

  bool get canAdd => pets.length < max;

  static const PetsPayload empty = PetsPayload();

  factory PetsPayload.fromJson(Map<String, dynamic> json) => PetsPayload(
        pets: Pet.listFrom(json['pets']),
        max: asInt(json['max'], fallback: 3),
      );
}

/// What a create/update actually did: the saved pet, the refreshed family, and
/// the paws the save earned — the toast the editor shows is that last number.
@immutable
class PetWrite {
  const PetWrite({required this.pet, this.pets = const [], this.pawsEarned = 0});

  final Pet pet;
  final List<Pet> pets;
  final int pawsEarned;

  factory PetWrite.fromJson(Map<String, dynamic> json) => PetWrite(
        pet: Pet.fromJson(asMap(json['pet'])),
        pets: Pet.listFrom(json['pets']),
        pawsEarned: asInt(json['paws_earned']),
      );
}
