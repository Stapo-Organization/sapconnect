import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../pets/data/household.dart';
import '../../pets/data/pet_models.dart';
import '../../pets/data/pets_repository.dart';

/// «لـ مشمش» — the pet a listing can be narrowed for.
///
/// The store's facet index speaks in species-neutral life stages
/// (`young` / `adult` / `senior`); a pet's birth date says which one it is.
/// When there is no birth date, the owner's one-tap answer on a listing
/// («كم عمر مشمش؟») is kept on the device under the household member key.
@immutable
class PetFit {
  const PetFit({
    required this.memberKey,
    required this.name,
    required this.species,
    this.life,
    this.weightKg,
  });

  final String memberKey;

  /// As the owner wrote it; empty when unnamed.
  final String name;
  final PetSpecies species;

  /// `young`, `adult`, `senior` — null until known.
  final String? life;
  final double? weightKg;

  @override
  bool operator ==(Object other) =>
      other is PetFit &&
      other.memberKey == memberKey &&
      other.name == name &&
      other.species == species &&
      other.life == life &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(memberKey, name, species, life, weightKg);
}

/// Life stage from a birth date. Cats and dogs are kittens/puppies for their
/// first year and seniors from seven — the thresholds pet food is labelled by.
String? lifeStageFor(DateTime? birth, {DateTime? now}) {
  if (birth == null) return null;
  final today = now ?? clock.now();
  final months = (today.year - birth.year) * 12 + today.month - birth.month - (today.day < birth.day ? 1 : 0);
  if (months < 0) return null;
  if (months < 12) return 'young';
  if (months >= 84) return 'senior';
  return 'adult';
}

/// The store's species key for an app species (only the four aisles).
PetSpecies? speciesFromAisle(String? key) => switch (key) {
      'cat' => PetSpecies.cat,
      'dog' => PetSpecies.dog,
      _ => null,
    };

/// Bumped when the owner answers «كم عمر…؟», so the fit recomputes.
class PetLifeAnswers extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> answer(String memberKey, String life) async {
    await ref.read(localStoreProvider).setPetLifeStage(memberKey, life);
    state++;
  }
}

final petLifeAnswersProvider = NotifierProvider<PetLifeAnswers, int>(PetLifeAnswers.new);

/// The household pet a listing of [aisle] (`cat`, `dog`) can be narrowed for:
/// the one the store is arranged for («تسوّق لـ») when it is of this species,
/// else the first of this species. Null when nobody at home eats from here.
final petFitProvider = Provider.autoDispose.family<PetFit?, String?>((ref, aisle) {
  final species = speciesFromAisle(aisle);
  if (species == null) return null;
  ref.watch(petLifeAnswersProvider);
  final household = ref.watch(householdProvider);

  HouseholdMember? member;
  var index = -1;
  final focus = household.focus;
  for (var i = 0; i < household.members.length; i++) {
    final m = household.members[i];
    if (m.species != species) continue;
    if (identical(m, focus)) {
      member = m;
      index = i;
      break;
    }
    if (member == null) {
      member = m;
      index = i;
    }
  }
  if (member == null) return null;

  Pet? pet;
  if (member.petId != null) {
    for (final p in ref.watch(petsProvider).value?.pets ?? const <Pet>[]) {
      if (p.id == member.petId) pet = p;
    }
  }
  final key = member.keyAt(index);
  String? stored;
  try {
    stored = ref.read(localStoreProvider).petLifeStage(key);
  } catch (_) {
    stored = null;
  }

  return PetFit(
    memberKey: key,
    name: member.name.trim(),
    species: species,
    life: lifeStageFor(pet?.birthDate) ?? stored,
    weightKg: pet?.weightKg,
  );
});
