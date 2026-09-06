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
    this.addressId,
    this.label,
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

  /// The saved address this point came from, when it came from one. Kept so
  /// the sheet can tick the row the customer is actually being delivered to.
  final String? addressId;

  /// What the customer calls this place — «المنزل», «العمل». The header says
  /// «يوصلك في المنزل» with it, and something vaguer without.
  final String? label;

  final DateTime? setAt;

  static const ZbLocation none = ZbLocation();

  bool get isSet => (city != null && city!.isNotEmpty) || (lat != null && lng != null);

  /// The address as a person says it — district first, then the city
  /// ("النرجس، الرياض"). Null when nothing is set.
  String? detailLabel(String locale) {
    final cityLabel = cityFor(locale);
    final districtLabel = _districtLabel(locale, cityLabel);
    final parts = [
      ?districtLabel,
      if (cityLabel != null && cityLabel.isNotEmpty) cityLabel,
    ];
    if (parts.isEmpty) return null;
    return parts.join(locale == 'ar' ? '، ' : ', ');
  }

  /// «حي الملك فهد» — the way the neighbourhood is said out loud, not the way
  /// the geocoder returns it.
  ///
  /// The word is only added where it is certainly true. A geocoder answers
  /// with all sorts of things: a Latin transliteration, the city itself on a
  /// coarse fix, «المنطقة الصناعية», «مخطط 12», «ضاحية …». None of those are
  /// حي, so anything that is not a plain Arabic neighbourhood name is left
  /// exactly as it came.
  String? _districtLabel(String locale, String? cityLabel) {
    final raw = district?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (locale != 'ar') return raw;
    if (raw == cityLabel || raw == city || raw == cityEn) return null;
    if (!_arabicOnly.hasMatch(raw)) return raw;
    if (_notADistrict.any(raw.startsWith)) return raw;
    return 'حي $raw';
  }

  /// Arabic letters and spaces only — no Latin, no digits.
  static final RegExp _arabicOnly = RegExp(r'^[\u0621-\u064A\u0670-\u06D3 ]+$');

  /// Openings that already name what the place is.
  static const List<String> _notADistrict = [
    'حي',
    'الحي',
    'مخطط',
    'المخطط',
    'ضاحية',
    'المنطقة',
    'منطقة',
    'مدينة',
    'قرية',
    'مركز',
    'طريق',
    'شارع',
  ];
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
        addressId: asStringOrNull(json['address_id']),
        label: asStringOrNull(json['label']),
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
        'address_id': addressId,
        'label': label,
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
    // The serving branch, so the catalogue cache is keyed to the shelf it
    // describes rather than to the city as a whole.
    if (warehouseCode != null && warehouseCode!.isNotEmpty) {
      headers['X-ZB-Branch'] = warehouseCode!;
    }
    return headers;
  }

  static String _headerSafe(String value) =>
      value.codeUnits.every((u) => u >= 0x20 && u < 0x7f) ? value : Uri.encodeComponent(value);
}

/// A device fix that no longer matches the saved delivery point, already
/// resolved so the offer can name the place. Nothing is applied until the
/// customer says so — a home address stays home while they sit at work.
@immutable
class LocationDrift {
  const LocationDrift({
    required this.lat,
    required this.lng,
    this.city,
    this.district,
    this.promiseLabel,
  });

  final double lat;
  final double lng;
  final String? city;
  final String? district;
  final String? promiseLabel;

  String? label(String locale) {
    final parts = [
      if (district != null && district!.trim().isNotEmpty) district!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(locale == 'ar' ? '، ' : ', ');
  }
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
  ///
  /// [addressId] and [label] travel with the point when it came from a saved
  /// address; both are cleared otherwise, because a pin dropped somewhere new
  /// is not «المنزل» any more.
  Future<bool> resolve(double lat, double lng, {String? addressId, String? label}) async {
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
          addressId: addressId,
          label: label,
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

  /// Far enough from the saved point to be a different neighbourhood.
  static const double driftMeters = 1200;

  /// Quietly checks whether the device has moved away from the saved delivery
  /// point. Never prompts for permission — an app that asks for location on
  /// every launch trains people to say no. Returns null when there is nothing
  /// to offer: no saved coordinates, no permission, no fix, no real distance,
  /// the same spot already waved away today, or the place could not be named.
  Future<LocationDrift?> detectDrift() async {
    final saved = state.location;
    if (!saved.hasCoordinates) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 6),
        ),
      );
      final moved = Geolocator.distanceBetween(
        saved.lat!, saved.lng!, fix.latitude, fix.longitude,
      );
      if (moved < driftMeters) return null;

      final dismissed = ref.read(localStoreProvider).driftDismissed;
      if (dismissed != null) {
        final at = asDate(dismissed['at']);
        final near = Geolocator.distanceBetween(
              asDoubleOrNull(dismissed['lat']) ?? 0,
              asDoubleOrNull(dismissed['lng']) ?? 0,
              fix.latitude,
              fix.longitude,
            ) <
            300;
        if (near && at != null && DateTime.now().difference(at) < const Duration(hours: 24)) {
          return null;
        }
      }

      final result = await ref
          .read(locationRepositoryProvider)
          .resolve(lat: fix.latitude, lng: fix.longitude);
      final drift = LocationDrift(
        lat: fix.latitude,
        lng: fix.longitude,
        city: result.city,
        district: result.district,
        promiseLabel: result.best?.promiseLabel,
      );
      return drift.label('ar') == null ? null : drift;
    } catch (_) {
      return null;
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
