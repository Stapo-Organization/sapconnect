import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import 'location_models.dart';

class LocationRepository {
  LocationRepository(this._api);

  final ApiClient _api;

  Future<List<CityEntry>> cities() async {
    final data = await _api.get('/location/cities');
    return asMapList(asMap(data)['cities']).map(CityEntry.fromJson).toList();
  }

  Future<ResolveResult> resolve({required double lat, required double lng}) async {
    final data = await _api.post('/location/resolve', body: {'lat': lat, 'lng': lng});
    return ResolveResult.fromJson(asMap(data));
  }
}

final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => LocationRepository(ref.watch(apiClientProvider)));

/// The city list changes about never, so it is cached for the session.
final citiesProvider = FutureProvider<List<CityEntry>>(
  (ref) => ref.watch(locationRepositoryProvider).cities(),
);
