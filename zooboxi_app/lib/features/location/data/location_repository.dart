import 'package:flutter/foundation.dart';
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

  /// Address search: place suggestions for [query], near the customer. The
  /// store holds the Google key; [session] groups one search's requests.
  Future<List<PlaceSuggestion>> search(String query, {double? lat, double? lng, required String session}) async {
    final data = await _api.get('/location/search', query: {
      'q': query,
      'session': session,
      if (lat != null) 'lat': lat.toStringAsFixed(5),
      if (lng != null) 'lng': lng.toStringAsFixed(5),
    });
    return asMapList(asMap(data)['results']).map(PlaceSuggestion.fromJson).toList();
  }

  /// Where a suggestion is: its coordinate.
  Future<({double lat, double lng})> place(String id, {required String session}) async {
    final data = asMap(asMap(await _api.get('/location/place', query: {'id': id, 'session': session}))['place']);
    return (lat: asDouble(data['lat']), lng: asDouble(data['lng']));
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

/// A dropped pin, as a *cache key*.
///
/// Equality is on the coordinate rounded to about a metre, so nudging the map
/// back to where it already was is answered from memory instead of over the
/// wire — a customer fine-tuning a doorstep moves back and forth a dozen
/// times, and each of those was a POST.
@immutable
class PinPoint {
  const PinPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  String get _key => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) => other is PinPoint && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// What the store says about the point under the pin: the place's name, and
/// whether — and how fast — anything can be delivered to it.
///
/// It is the same resolver the header chip uses, so the city a pinned address
/// carries is one the store already knows how to route.
final pinPlaceProvider = FutureProvider.autoDispose.family<ResolveResult, PinPoint>(
  (ref, point) =>
      ref.watch(locationRepositoryProvider).resolve(lat: point.lat, lng: point.lng),
);
