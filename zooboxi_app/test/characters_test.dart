import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/core/characters/characters.dart';
import 'package:zooboxi_app/core/characters/companion.dart';
import 'package:zooboxi_app/core/characters/scenes.dart';
import 'package:zooboxi_app/core/providers.dart';
import 'package:zooboxi_app/core/session/session_controller.dart';
import 'package:zooboxi_app/core/storage/local_store.dart';
import 'package:zooboxi_app/features/pets/data/household.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/data/pets_repository.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

Finder _asset(String key) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == stickerAsset(key),
      description: 'sticker $key',
    );

Future<LocalStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalStore(await SharedPreferences.getInstance());
}

Widget _host(LocalStore store, Widget child, {List overrides = const []}) => ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store), ...overrides],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );

class _Authed extends SessionController {
  @override
  SessionState build() => const SessionState(status: AuthStatus.authenticated, token: 't');
}

/// A server family: what `/pets` holds, and every create it receives.
class _FakePets implements PetsRepository {
  _FakePets(this.onFile, {this.max = 3});

  final List<Pet> onFile;
  final int max;
  final List<Pet> created = [];

  @override
  Future<PetsPayload> pets() async => PetsPayload(pets: [...onFile, ...created], max: max);

  @override
  Future<PetWrite> create(Pet pet) async {
    final saved = Pet(id: 100 + created.length, name: pet.name, species: pet.species, sex: pet.sex);
    created.add(saved);
    return PetWrite(pet: saved, pets: [...onFile, ...created]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('every sticker in the table is a bundled file', () {
    for (final key in [
      for (final pose in ZbPose.values) ...[castStickerKey(ZbCast.cat, pose), castStickerKey(ZbCast.dog, pose)],
      for (final cast in ZbCast.values) castStickerKey(cast, ZbPose.sitUp),
      for (final prop in ZbProp.values) prop.key,
    ]) {
      expect(File(stickerAsset(key)).existsSync(), isTrue, reason: key);
      expect(stickerArt(key).artAspect, greaterThan(0), reason: key);
    }
  });

  group('who plays the part', () {
    test('the household decides, the screen default fills in', () {
      expect(Companion.resolve(ZbPose.wow, null, ZbCast.cat), ZbCast.cat);
      expect(Companion.resolve(ZbPose.wow, ZbCast.dog, ZbCast.cat), ZbCast.dog);
      expect(Companion.resolve(ZbPose.sitUp, ZbCast.budgie, ZbCast.dog), ZbCast.budgie);
    });

    test('a one-pose species never plays a silhouette the layout depends on', () {
      expect(Companion.resolve(ZbPose.peekSide, ZbCast.fish, ZbCast.dog), ZbCast.dog);
      expect(Companion.resolve(ZbPose.sleep, ZbCast.turtle, ZbCast.cat), ZbCast.cat);
      expect(Companion.resolve(ZbPose.peek, ZbCast.budgie, ZbCast.fish), ZbCast.cat);
    });

    test('species map onto the drawn cast', () {
      expect(castForSpecies(PetSpecies.bird), ZbCast.budgie);
      expect(castForSpecies(PetSpecies.small), ZbCast.hamster);
      expect(castForSpecies(PetSpecies.reptile), ZbCast.turtle);
      expect(castForSpecies(PetSpecies.other), isNull);
    });
  });

  group('the wishlist scene follows the household', () {
    for (final (species, expected) in [('cat', 'cat-wow'), ('dog', 'dog-wow'), ('bird', 'budgie')]) {
      testWidgets('a $species home sees $expected', (tester) async {
        final store = await _store({
          'pets.household.v1': '[{"species":"$species"}]',
        });
        await tester.pumpWidget(_host(store, const WishlistScene()));
        await tester.pump();
        expect(_asset(expected), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an unknown home keeps the designed default', (tester) async {
      await tester.pumpWidget(_host(await _store(), const WishlistScene()));
      await tester.pump();
      expect(_asset('cat-wow'), findsOneWidget);
    });
  });

  group('a guest household becomes pets at sign-in', () {
    Future<(ProviderContainer, _FakePets)> signIn(List<Pet> onFile, String household, {int max = 3}) async {
      final store = await _store({'pets.household.v1': household});
      final fake = _FakePets(onFile, max: max);
      final container = ProviderContainer(overrides: [
        localStoreProvider.overrideWithValue(store),
        petsRepositoryProvider.overrideWithValue(fake),
        sessionProvider.overrideWith(_Authed.new),
      ]);
      addTearDown(container.dispose);
      await container.read(householdProvider.notifier).adoptGuestHousehold(unnamed: (s) => 'قطة');
      return (container, fake);
    }

    test('each described animal is created once, unnamed ones under their kind', () async {
      final (container, fake) = await signIn([], '[{"species":"cat","name":"مشمش","sex":"f"},{"species":"cat"}]');
      expect(fake.created.map((p) => p.name), ['مشمش', 'قطة']);
      expect(fake.created.first.sex, 'f');
      expect(container.read(localStoreProvider).household, isEmpty);
    });

    test('an animal already on file is not duplicated — but a second one is added', () async {
      final (_, fake) = await signIn(
        [const Pet(id: 1, name: 'بندق', species: PetSpecies.cat)],
        '[{"species":"cat"},{"species":"cat"}]',
      );
      expect(fake.created, hasLength(1));
    });

    test('the family ceiling is respected', () async {
      final (_, fake) = await signIn(
        [const Pet(id: 1, name: 'بندق', species: PetSpecies.dog), const Pet(id: 2, name: 'لولو', species: PetSpecies.dog)],
        '[{"species":"cat"},{"species":"cat"}]',
      );
      expect(fake.created, hasLength(1));
    });
  });
}
