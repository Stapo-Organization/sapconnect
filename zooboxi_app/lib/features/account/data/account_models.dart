import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// A saved delivery address. Coordinates are part of the identity, not a
/// nicety: the store resolves the delivery tier from the pin, not the text.
@immutable
class Address {
  const Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.addressLine,
    this.label,
    this.district,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final String id;
  final String? label;
  final String name;
  final String phone;
  final String city;
  final String? district;
  final String addressLine;
  final double? lat;
  final double? lng;
  final bool isDefault;

  /// One-line summary for a list row.
  String get summary =>
      [district, city].where((e) => e != null && e.isNotEmpty).join('، ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: asString(json['id']),
        label: asStringOrNull(json['label']),
        name: asString(json['name']),
        phone: asString(json['phone']),
        city: asString(json['city']),
        district: asStringOrNull(json['district']),
        addressLine: asString(json['address_line']),
        lat: asDoubleOrNull(json['lat']),
        lng: asDoubleOrNull(json['lng']),
        isDefault: asBool(json['is_default']),
      );

  Map<String, dynamic> toJson() => {
        'label': ?label,
        'name': name,
        'phone': phone,
        'city': city,
        'district': ?district,
        'address_line': addressLine,
        'lat': ?lat,
        'lng': ?lng,
      };
}
