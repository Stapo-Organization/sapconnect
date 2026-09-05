import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import 'care_models.dart';
import 'pet_models.dart';

class PetsRepository {
  PetsRepository(this._api);

  final ApiClient _api;

  Future<PetsPayload> pets() async =>
      PetsPayload.fromJson(asMap(await _api.get('/pets')));

  /// Every write answers with the whole family plus the paws it earned, so the
  /// list and the wallet can never drift from a locally spliced copy.
  Future<PetWrite> create(Pet pet) async =>
      PetWrite.fromJson(asMap(await _api.post('/pets', body: pet.toJson())));

  Future<PetWrite> update(int id, Pet pet) async =>
      PetWrite.fromJson(asMap(await _api.patch('/pets/$id', body: pet.toJson())));

  /// Soft delete server-side — the ledger entries that named this pet stay
  /// truthful.
  Future<List<Pet>> remove(int id) async =>
      Pet.listFrom(await _api.delete('/pets/$id'));

  // ── «الرفيق» ──

  Future<PetCare> care(int id) async => PetCare.fromJson(asMap(await _api.get('/pets/$id/care')));

  /// One reading; the same day twice updates in place.
  Future<PetCare> logWeight(int id, double kg, {DateTime? on}) async => PetCare.fromJson(asMap(await _api.post(
        '/pets/$id/weights',
        body: {'weight_kg': kg, if (on != null) 'on': _isoDate(on)},
      )));

  Future<PetCare> deleteWeight(int id, int weightId) async =>
      PetCare.fromJson(asMap(await _api.delete('/pets/$id/weights/$weightId')));

  /// Edit a reminder: any of the last date, the next date, the interval, on/off.
  Future<PetCare> setReminder(
    int id,
    String kind, {
    DateTime? lastOn,
    DateTime? nextOn,
    int? intervalDays,
    bool? enabled,
  }) async {
    final last = lastOn == null ? null : _isoDate(lastOn);
    final next = nextOn == null ? null : _isoDate(nextOn);
    return PetCare.fromJson(asMap(await _api.patch('/pets/$id/care/$kind', body: {
      'last_on': ?last,
      'next_on': ?next,
      'interval_days': ?intervalDays,
      'enabled': ?enabled,
    })));
  }

  /// «تم» — done today (or on [on]); the next date follows the interval.
  Future<PetCare> markDone(int id, String kind, {DateTime? on}) async => PetCare.fromJson(asMap(await _api.post(
        '/pets/$id/care/$kind/done',
        body: {if (on != null) 'on': _isoDate(on)},
      )));

  /// The plan's inputs live on the pet itself.
  Future<PetWrite> updatePlanInputs(
    int id, {
    String? activity,
    String? bodyCondition,
    double? feedGDay,
    bool clearFeedGDay = false,
    int? foodKcal,
    bool clearFoodKcal = false,
  }) async =>
      PetWrite.fromJson(asMap(await _api.patch('/pets/$id', body: {
        'activity': ?activity,
        'body_condition': ?bodyCondition,
        'feed_g_day': ?feedGDay,
        if (clearFeedGDay) 'feed_g_day': null,
        'food_kcal': ?foodKcal,
        if (clearFoodKcal) 'food_kcal': null,
      })));

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

final petsRepositoryProvider =
    Provider<PetsRepository>((ref) => PetsRepository(ref.watch(apiClientProvider)));

/// One pet's care profile. Signed-out resolves to nothing rather than a 401.
final petCareProvider = FutureProvider.autoDispose.family<PetCare?, int>((ref, petId) {
  if (!ref.watch(sessionProvider).isAuthenticated || petId <= 0) {
    return Future.value(null);
  }
  return ref.watch(petsRepositoryProvider).care(petId);
});

/// «عائلتي». A guest has no family on file, so this resolves empty rather
/// than firing a call that would 401.
final petsProvider = FutureProvider.autoDispose<PetsPayload>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(PetsPayload.empty);
  }
  return ref.watch(petsRepositoryProvider).pets();
});
