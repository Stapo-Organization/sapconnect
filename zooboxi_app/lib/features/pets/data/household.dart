import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/characters/characters.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/storage/local_store.dart';
import 'pet_models.dart';
import 'pets_repository.dart';

/// «مين معك في البيت؟» — the animals the app is arranged around.
///
/// One list for everyone: a signed-in customer's «عائلتي» from the server, or
/// the household a guest described in the welcome journey, kept on the device
/// until sign-in turns it into real pets.
@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.species,
    this.name = '',
    this.sex = '',
    this.petId,
  });

  final PetSpecies species;
  final String name;

  /// `m`, `f`, or empty.
  final String sex;

  /// The server pet this member is, once it is one.
  final int? petId;

  /// Stable across a session: the pet id, or the position in the guest list.
  String keyAt(int index) => petId != null ? 'p$petId' : 'g$index';

  factory HouseholdMember.fromPet(Pet pet) => HouseholdMember(
    species: pet.species,
    name: pet.name,
    sex: pet.sex,
    petId: pet.id,
  );

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      HouseholdMember(
        species: PetSpecies.fromKey(json['species'] as String?),
        name: (json['name'] as String?) ?? '',
        sex: (json['sex'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'species': species.key,
    if (name.isNotEmpty) 'name': name,
    if (sex.isNotEmpty) 'sex': sex,
  };

  HouseholdMember copyWith({String? name, String? sex}) => HouseholdMember(
    species: species,
    name: name ?? this.name,
    sex: sex ?? this.sex,
    petId: petId,
  );
}

@immutable
class Household {
  const Household({
    this.members = const [],
    this.shopsForOthers = false,
    this.shoppingFor,
  });

  final List<HouseholdMember> members;
  final bool shopsForOthers;

  /// The member key the store is arranged for, or null for everyone.
  final String? shoppingFor;

  bool get isEmpty => members.isEmpty;

  /// The member the app speaks to: the one picked in «تسوّق لـ», else the
  /// first in the family.
  HouseholdMember? get focus {
    if (members.isEmpty) return null;
    final key = shoppingFor;
    if (key != null) {
      for (var i = 0; i < members.length; i++) {
        if (members[i].keyAt(i) == key) return members[i];
      }
    }
    return members.first;
  }

  /// The species set, in family order, without repeats.
  List<PetSpecies> get species => {for (final m in members) m.species}.toList();

  /// The species the store is asked to arrange the page for: the animal picked
  /// in «تسوّق لـ», or the family's only kind. «الكل» over a mixed family asks
  /// for nothing in particular.
  PetSpecies? get feedSpecies {
    if (shoppingFor != null) return focus?.species;
    final kinds = species;
    return kinds.length == 1 ? kinds.first : null;
  }
}

/// The drawn cast member for a species; null when we have no drawing for it.
ZbCast? castForSpecies(PetSpecies species) => switch (species) {
  PetSpecies.cat => ZbCast.cat,
  PetSpecies.dog => ZbCast.dog,
  PetSpecies.bird => ZbCast.budgie,
  PetSpecies.fish => ZbCast.fish,
  PetSpecies.small => ZbCast.hamster,
  PetSpecies.reptile => ZbCast.turtle,
  PetSpecies.other => null,
};

class HouseholdController extends Notifier<Household> {
  @override
  Household build() {
    // The household only dresses the screens; where there is no device
    // store (a bare widget test, a preview) it is simply unknown.
    final LocalStore store;
    try {
      store = ref.watch(localStoreProvider);
    } catch (_) {
      return const Household();
    }
    final authed = ref.watch(sessionProvider.select((s) => s.isAuthenticated));
    final List<HouseholdMember> members;
    if (authed) {
      final pets = ref.watch(petsProvider).value?.pets ?? const <Pet>[];
      // Until the family loads, a customer who just signed in still sees the
      // household they described as a guest.
      members = pets.isNotEmpty
          ? pets.map(HouseholdMember.fromPet).toList()
          : store.household.map(HouseholdMember.fromJson).toList();
    } else {
      members = store.household.map(HouseholdMember.fromJson).toList();
    }
    return Household(
      members: members,
      shopsForOthers: store.shopsForOthers,
      shoppingFor: store.shoppingFor,
    );
  }

  /// The welcome journey's answer. A signed-in customer's animals become real
  /// pets straight away; a guest's wait on the device.
  Future<void> describe(
    List<HouseholdMember> members, {
    bool shopsForOthers = false,
    String Function(PetSpecies species)? unnamed,
  }) async {
    final store = ref.read(localStoreProvider);
    await store.setShopsForOthers(shopsForOthers);
    await store.setShoppingFor(null);
    await store.setHousehold(members.map((m) => m.toJson()).toList());
    if (ref.read(sessionProvider).isAuthenticated) {
      await adoptGuestHousehold(unnamed: unnamed);
    }
    ref.invalidateSelf();
  }

  Future<void> shopFor(String? key) async {
    await ref.read(localStoreProvider).setShoppingFor(key);
    ref.invalidateSelf();
  }

  /// Turns the household a guest described into pets on their account — the
  /// same promise the guest address makes. Animals already on file are not
  /// duplicated. Never throws; what fails stays on the
  /// device for the next attempt.
  Future<void> adoptGuestHousehold({
    String Function(PetSpecies species)? unnamed,
  }) async {
    final store = ref.read(localStoreProvider);
    final pending = store.household.map(HouseholdMember.fromJson).toList();
    if (pending.isEmpty) return;
    final repository = ref.read(petsRepositoryProvider);
    try {
      final payload = await repository.pets();
      final have = [...payload.pets];
      // Each animal already on file can account for one described animal —
      // two unnamed cats against one cat on file still adds the second.
      final unmatched = [...payload.pets];
      final left = <HouseholdMember>[];
      for (final member in pending) {
        final match = unmatched.indexWhere(
          (p) =>
              p.species == member.species &&
              (member.name.isEmpty || p.name.trim() == member.name.trim()),
        );
        if (match >= 0) {
          unmatched.removeAt(match);
          continue;
        }
        if (have.length >= payload.max) break;
        try {
          final write = await repository.create(
            Pet(
              id: 0,
              // A pet needs a name on file; an animal the guest did not name
              // is filed under its kind until they rename it.
              name: member.name.isNotEmpty
                  ? member.name
                  : (unnamed?.call(member.species) ?? member.species.key),
              species: member.species,
              sex: member.sex,
            ),
          );
          have.add(write.pet);
        } catch (_) {
          left.add(member);
        }
      }
      await store.setHousehold(left.map((m) => m.toJson()).toList());
      ref.invalidate(petsProvider);
    } catch (_) {
      // Offline or a server hiccup: try again at the next sign-in or launch.
    }
  }
}

final householdProvider = NotifierProvider<HouseholdController, Household>(
  HouseholdController.new,
);

/// The cast member who stands in for the customer's own animal, or null when
/// the app does not know one (then each screen keeps its designed default).
final companionCastProvider = Provider<ZbCast?>((ref) {
  final household = ref.watch(householdProvider);
  if (household.shopsForOthers && household.isEmpty) return null;
  final focus = household.focus;
  return focus == null ? null : castForSpecies(focus.species);
});
