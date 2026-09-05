import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
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
}

final petsRepositoryProvider =
    Provider<PetsRepository>((ref) => PetsRepository(ref.watch(apiClientProvider)));

/// «عائلتي». A guest has no family on file, so this resolves empty rather
/// than firing a call that would 401.
final petsProvider = FutureProvider.autoDispose<PetsPayload>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(PetsPayload.empty);
  }
  return ref.watch(petsRepositoryProvider).pets();
});
