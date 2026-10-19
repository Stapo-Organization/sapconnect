import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/characters/characters.dart';
import '../../../../core/providers.dart';
import '../../../../core/session/session_controller.dart';
import '../../../pets/data/household.dart';
import '../../../pets/data/pets_repository.dart';

/// The animal who greets a returning customer on the splash.
@immutable
class SplashCompanion {
  const SplashCompanion({required this.cast, this.name = ''});

  final ZbCast cast;

  /// As the customer wrote it; empty when the pet has no name on file.
  final String name;

  Map<String, String> toJson() => {'cast': cast.name, 'name': name};

  static SplashCompanion? fromJson(Map<String, String>? json) {
    if (json == null) return null;
    for (final cast in ZbCast.values) {
      if (cast.name == json['cast']) {
        return SplashCompanion(cast: cast, name: (json['name'] ?? '').trim());
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SplashCompanion && other.cast == cast && other.name == name;

  @override
  int get hashCode => Object.hash(cast, name);
}

/// Which story the splash tells. Both open on the same picture — the whole
/// logo, 170 wide, centred on the launch canvas — because the native launch
/// screen is one picture for everyone and the first Flutter frame must match
/// it.
sealed class SplashPlan {
  const SplashPlan();

  /// When the intro has said everything it has to say; the exit may start
  /// from here on.
  Duration get intro;
}

/// «الانفجار المبهج» — first launch, or nobody on file: the teal ground bursts
/// out from behind the logo, the rays turn, the confetti flies.
class BurstPlan extends SplashPlan {
  const BurstPlan();

  @override
  Duration get intro => const Duration(milliseconds: 1150);
}

/// «أهلاً لولو» — a returning customer: their own animal comes up on the teal
/// hill and waves, under a greeting with its name.
class HelloPlan extends SplashPlan {
  const HelloPlan(this.companion);

  final SplashCompanion companion;

  @override
  Duration get intro => const Duration(milliseconds: 1350);
}

/// Read once, synchronously, from the device: the splash never waits on the
/// network, so it greets whoever was on file at the end of the last session.
final splashPlanProvider = Provider<SplashPlan>((ref) {
  final companion = SplashCompanion.fromJson(ref.watch(localStoreProvider).splashCompanion);
  return companion == null ? const BurstPlan() : HelloPlan(companion);
});

/// The companion as the app knows it *for certain*, or `(known: false)` while
/// it is still guessing — before the session is restored, or while a signed-in
/// customer's pets are loading. Only a certain answer is written down, so a
/// cold start that has not heard from the server yet never erases the pet the
/// last session knew.
final splashCompanionTruthProvider = Provider<({bool known, SplashCompanion? companion})>((ref) {
  final session = ref.watch(sessionProvider);
  if (!session.isReady) return (known: false, companion: null);
  if (session.isAuthenticated && !ref.watch(petsProvider).hasValue) {
    return (known: false, companion: null);
  }
  final household = ref.watch(householdProvider);
  final focus = household.shopsForOthers && household.isEmpty ? null : household.focus;
  final cast = focus == null ? null : castForSpecies(focus.species);
  return (
    known: true,
    companion: cast == null ? null : SplashCompanion(cast: cast, name: focus!.name.trim()),
  );
});

enum SplashPhase { intro, exit, gone }

@immutable
class SplashState {
  const SplashState({this.phase = SplashPhase.intro, this.flyToSign = false});

  final SplashPhase phase;

  /// The logo ends its flight in the زوبكسي storefront sign — only when home
  /// is what the splash uncovers.
  final bool flyToSign;
}

/// Sequences the hand-off between the boot route, which knows when the app
/// is ready and where it goes, and the stage above the navigator, which draws
/// the splash and uncovers that destination.
class SplashController extends Notifier<SplashState> {
  @override
  SplashState build() => const SplashState();

  /// The destination is on screen under the stage: play the way out.
  void leave({required bool flyToSign}) {
    if (state.phase != SplashPhase.intro) return;
    state = SplashState(phase: SplashPhase.exit, flyToSign: flyToSign);
  }

  /// The stage has finished and can come down.
  void finish() => state = SplashState(phase: SplashPhase.gone, flyToSign: state.flyToSign);
}

final splashControllerProvider = NotifierProvider<SplashController, SplashState>(SplashController.new);
