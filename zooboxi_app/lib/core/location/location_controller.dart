import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/location/data/location_models.dart';
import '../../features/location/data/location_repository.dart';
import '../network/envelope.dart';
import '../providers.dart';

/// Where we are delivering to. Everything the catalog shows — stock counts,
/// badges, delivery chips, cart caps — is scoped to this, because the store's
/// fulfilment engine resolves a different nearest branch per coordinate.
@immutable
class ZbLocation {
  const ZbLocation({
    this.lat,
    this.lng,
    this.city,
    this.cityEn,
    this.district,
    this.deliveryType,
    this.warehouseCode,
    this.warehouseName,
    this.promiseLabel,
    this.setAt,
  });

  final double? lat;
  final double? lng;
  final String? city;
  final String? cityEn;
  final String? district;

  /// `express` | `same_day` | `shipping` | `pickup` — the tier the server
  /// picked as best for this point.
  final String? deliveryType;
  final String? warehouseCode;
  final String? warehouseName;

  /// Human promise for the header chip, e.g. "خلال ساعتين".
  final String? promiseLabel;
  final DateTime? setAt;

  static const ZbLocation none = ZbLocation();

  bool get isSet => (city != null && city!.isNotEmpty) || (lat != null && lng != null);

  /// The address as a person says it — district first, then the city
  /// ("النرجس، الرياض"). Null when nothing is set.
  String? detailLabel(String locale) {
    final cityLabel = cityFor(locale);
    final parts = [
      if (district != null && district!.trim().isNotEmpty) district!.trim(),
      if (cityLabel != null && cityLabel.isNotEmpty) cityLabel,
    ];
    if (parts.isEmpty) return null;
    return parts.join(locale == 'ar' ? '، ' : ', ');
  }
  bool get hasCoordinates => lat != null && lng != null;

  /// Coordinates drift: a customer who set their location a month ago may well
  /// be somewhere else. We re-prompt softly rather than silently mis-promising.
  bool get isStale {
    final at = setAt;
    if (at == null) return isSet;
    return DateTime.now().difference(at) > const Duration(days: 30);
  }

  /// City name in [languageCode], falling back to whichever we have.
  String? cityFor(String languageCode) =>
      languageCode == 'en' ? (cityEn ?? city) : (city ?? cityEn);

  factory ZbLocation.fromJson(Map<String, dynamic> json) => ZbLocation(
        lat: asDoubleOrNull(json['lat']),
        lng: asDoubleOrNull(json['lng']),
        city: asStringOrNull(json['city']),
        cityEn: asStringOrNull(json['city_en']),
        district: asStringOrNull(json['district']),
        deliveryType: asStringOrNull(json['delivery_type']),
        warehouseCode: asStringOrNull(json['warehouse_code']),
        warehouseName: asStringOrNull(json['warehouse_name']),
        promiseLabel: asStringOrNull(json['promise_label']),
        setAt: asDate(json['set_at']),
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'city': city,
        'city_en': cityEn,
        'district': district,
        'delivery_type': deliveryType,
        'warehouse_code': warehouseCode,
        'warehouse_name': warehouseName,
        'promise_label': promiseLabel,
        'set_at': (setAt ?? DateTime.now()).toIso8601String(),
      };

  /// The headers that make the store's 44 location-aware classes work: the app
  /// is the cookie jar the web session normally provides.
  ///
  /// City/district are Arabic, and dart:io refuses to SEND a header whose value
  /// isn't Latin-1 — every request would die on-device with what looks like a
  /// network failure. So non-ASCII values travel percent-encoded; the server's
  /// v2 bootstrap rawurldecode()s them before seeding the cookie jar.
  Map<String, String> headersMap() {
    final headers = <String, String>{};
    if (lat != null) headers['X-ZB-Lat'] = lat!.toStringAsFixed(6);
    if (lng != null) headers['X-ZB-Lng'] = lng!.toStringAsFixed(6);
    if (city != null && city!.isNotEmpty) headers['X-ZB-City'] = _headerSafe(city!);
    if (district != null && district!.isNotEmpty) {
      headers['X-ZB-District'] = _headerSafe(district!);
    }
    if (deliveryType != null && deliveryType!.isNotEmpty) {
      headers['X-ZB-Delivery-Type'] = deliveryType!;
    }
    return headers;
  }

  static String _headerSafe(String value) =>
      value.codeUnits.every((u) => u >= 0x20 && u < 0x7f) ? value : Uri.encodeComponent(value);
}

/// How the last location resolution went — drives the welcome step and the
/// location sheet without either needing a second piece of state.
enum LocationPhase { idle, locating, denied, failed }

@immutable
class LocationState {
  const LocationState({this.location = ZbLocation.none, this.phase = LocationPhase.idle});

  final ZbLocation location;
  final LocationPhase phase;

  bool get isBusy => phase == LocationPhase.locating;

  LocationState copyWith({ZbLocation? location, LocationPhase? phase}) =>
      LocationState(location: location ?? this.location, phase: phase ?? this.phase);
}

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() {
    final saved = ref.read(localStoreProvider).location;
    if (saved == null) return const LocationState();
    return LocationState(location: ZbLocation.fromJson(saved));
  }

  /// Asks the OS for a fix, then hands the coordinates to the server, which
  /// owns the actual answer ("which branch reaches this point, how fast").
  /// We never guess a warehouse client-side.
  Future<bool> useDeviceLocation() async {
    state = state.copyWith(phase: LocationPhase.locating);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = state.copyWith(phase: LocationPhase.failed);
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(phase: LocationPhase.denied);
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return resolve(position.latitude, position.longitude);
    } catch (_) {
      state = state.copyWith(phase: LocationPhase.failed);
      return false;
    }
  }

  /// Resolves raw coordinates through the server's fulfilment engine.
  Future<bool> resolve(double lat, double lng) async {
    state = state.copyWith(phase: LocationPhase.locating);
    try {
      final result = await ref.read(locationRepositoryProvider).resolve(lat: lat, lng: lng);
      final best = result.best;
      await _apply(
        ZbLocation(
          lat: lat,
          lng: lng,
          city: result.city,
          district: result.district,
          deliveryType: best?.deliveryType,
          warehouseCode: best?.warehouseCode,
          warehouseName: best?.warehouseName,
          promiseLabel: best?.promiseLabel,
          setAt: DateTime.now(),
        ),
      );
      state = state.copyWith(phase: LocationPhase.idle);
      return true;
    } catch (_) {
      state = state.copyWith(phase: LocationPhase.failed);
      return false;
    }
  }

  /// Picking a city from the list. Its central-warehouse coordinates stand in
  /// for a GPS fix — good enough for city-level availability, and it lets the
  /// customer skip the permission prompt entirely.
  Future<void> setCity(CityEntry city) async {
    await _apply(
      ZbLocation(
        lat: city.lat,
        lng: city.lng,
        city: city.city,
        cityEn: city.nameEn,
        warehouseCode: city.warehouseCode,
        setAt: DateTime.now(),
      ),
    );
    state = state.copyWith(phase: LocationPhase.idle);
    // A city centroid is a coarse fix; ask the server to sharpen it into a
    // real tier + branch when it can.
    if (city.lat != null && city.lng != null) {
      unawaited(resolve(city.lat!, city.lng!));
    }
  }

  Future<void> clear() async {
    await _apply(ZbLocation.none);
    state = state.copyWith(phase: LocationPhase.idle);
  }

  void resetPhase() {
    if (state.phase != LocationPhase.idle) {
      state = state.copyWith(phase: LocationPhase.idle);
    }
  }

  Future<void> _apply(ZbLocation location) async {
    state = state.copyWith(location: location);
    await ref
        .read(localStoreProvider)
        .setLocation(location.isSet ? location.toJson() : null);

    // Everything cached describes the *previous* location's availability.
    await ref.read(apiClientProvider).clearCache();
    ref.read(catalogRevisionProvider.notifier).bump();
  }
}

final locationProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

/// Read-only view for the many widgets that just want the current place.
final currentLocationProvider =
    Provider<ZbLocation>((ref) => ref.watch(locationProvider).location);

void unawaited(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}
