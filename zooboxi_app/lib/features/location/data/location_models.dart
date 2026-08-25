import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// One row of `GET /location/cities` — a city the store serves, plus the
/// coordinates of its central warehouse (used as a stand-in fix when the
/// customer picks a city instead of granting GPS).
@immutable
class CityEntry {
  const CityEntry({
    required this.city,
    this.nameEn,
    this.warehouseCode,
    this.lat,
    this.lng,
  });

  final String city;
  final String? nameEn;
  final String? warehouseCode;
  final double? lat;
  final double? lng;

  // Server shape: { city, has_central, central: { code, name, lat, lng } | null }.
  factory CityEntry.fromJson(Map<String, dynamic> json) {
    final central = asMap(json['central']);
    return CityEntry(
      city: asString(json['city']),
      nameEn: asStringOrNull(central['name']) ?? asStringOrNull(json['name']),
      warehouseCode: asStringOrNull(central['code']) ?? asStringOrNull(json['warehouse_code']),
      lat: asDoubleOrNull(central['lat']) ?? asDoubleOrNull(json['lat']),
      lng: asDoubleOrNull(central['lng']) ?? asDoubleOrNull(json['lng']),
    );
  }

  String nameFor(String languageCode) =>
      languageCode == 'en' ? (nameEn ?? city) : city;
}

/// One fulfilment route the server found for a point: which warehouse serves
/// it, under which tier, and what to promise the customer.
@immutable
class DeliveryOption {
  const DeliveryOption({
    required this.deliveryType,
    this.warehouseCode,
    this.warehouseName,
    this.etaLabel,
    this.fee,
  });

  final String deliveryType;
  final String? warehouseCode;
  final String? warehouseName;
  final String? etaLabel;
  final double? fee;

  /// The promise shown on the header chip.
  String? get promiseLabel => etaLabel;

  factory DeliveryOption.fromJson(String type, Map<String, dynamic> json) => DeliveryOption(
        deliveryType: asString(json['delivery_type'], fallback: type),
        warehouseCode: asStringOrNull(json['warehouse_code']),
        warehouseName: asStringOrNull(json['warehouse_name']),
        etaLabel: asStringOrNull(json['estimated_time']) ??
            asStringOrNull(json['eta_label']) ??
            asStringOrNull(json['label']),
        fee: asDoubleOrNull(json['fee']),
      );
}

/// `POST /location/resolve` — the reverse-geocoded place plus every route that
/// reaches it, with the server's own pick in [best].
@immutable
class ResolveResult {
  const ResolveResult({
    this.city,
    this.district,
    this.options = const [],
    this.pickupPoints = const [],
    this.best,
  });

  final String? city;
  final String? district;
  final List<DeliveryOption> options;
  final List<DeliveryOption> pickupPoints;
  final DeliveryOption? best;

  factory ResolveResult.fromJson(Map<String, dynamic> json) {
    final rawOptions = asMap(json['options']);
    final options = <DeliveryOption>[];
    final pickups = <DeliveryOption>[];

    rawOptions.forEach((key, value) {
      if (key == 'pickup') {
        for (final entry in asMapList(value)) {
          pickups.add(DeliveryOption.fromJson('pickup', entry));
        }
        return;
      }
      if (value is Map) {
        options.add(DeliveryOption.fromJson(key, Map<String, dynamic>.from(value)));
      }
    });

    final bestJson = asMap(json['best']);
    return ResolveResult(
      city: asStringOrNull(json['city']),
      district: asStringOrNull(json['district']),
      options: options,
      pickupPoints: pickups,
      best: bestJson.isEmpty
          ? null
          : DeliveryOption(
              deliveryType: asString(bestJson['delivery_type'], fallback: 'shipping'),
              warehouseCode: asStringOrNull(bestJson['warehouse_code']),
              warehouseName: asStringOrNull(bestJson['warehouse_name']),
              etaLabel: asStringOrNull(bestJson['promise_label']),
            ),
    );
  }
}
