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
    this.building,
    this.floor,
    this.apartment,
    this.lat,
    this.lng,
    this.email,
    this.isDefault = false,
    this.createdAt,
    this.serves = true,
    this.servesReason = '',
  });

  final String id;
  final String? label;
  final String name;
  final String phone;
  final String city;
  final String? district;
  final String addressLine;

  /// The last few metres. A pin plus a building/floor/flat is what turns
  /// "somewhere on this street" into a door the driver can knock on.
  final String? building;
  final String? floor;
  final String? apartment;
  final double? lat;
  final double? lng;

  /// Only ever sent — the address book never reads one back. It exists so a
  /// receipt can reach a customer who signed up with a phone number alone.
  final String? email;
  final bool isDefault;
  final DateTime? createdAt;

  /// Whether the basket being checked out can actually be sent here.
  ///
  /// An إكسبريس basket was quoted against ONE branch — its stock, its clock,
  /// its courier — so an address that branch does not cover is not a slower
  /// delivery, it is a different warehouse where the chosen quantities may
  /// not exist. Only `GET /checkout` knows this; everywhere else the address
  /// book is just a book, and the default of `true` is what every screen
  /// outside checkout means.
  final bool serves;

  /// Why not: `out_of_zone` | `no_pin`, empty when it does.
  final String servesReason;

  /// True once this entry exists server-side and can be referenced by id.
  bool get isSaved => id.isNotEmpty;

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
        building: asStringOrNull(json['building']),
        floor: asStringOrNull(json['floor']),
        apartment: asStringOrNull(json['apartment']),
        lat: asDoubleOrNull(json['lat']),
        lng: asDoubleOrNull(json['lng']),
        isDefault: asBool(json['is_default']),
        createdAt: asDate(json['created_at']),
        // Absent everywhere except checkout, and absent from a store that
        // predates the check — both mean "nothing says otherwise".
        serves: json.containsKey('serves') ? asBool(json['serves']) : true,
        servesReason: asString(json['serves_reason']),
      );

  /// The write shape. `is_default` only rides along when it is being *set* —
  /// sending `false` on every edit would fight the server's rule that the book
  /// always keeps exactly one default.
  Map<String, dynamic> toJson({bool includeDefault = false}) => {
        'label': ?label,
        'name': name,
        'phone': phone,
        'city': city,
        'district': ?district,
        'address_line': addressLine,
        'building': ?building,
        'floor': ?floor,
        'apartment': ?apartment,
        'lat': ?lat,
        'lng': ?lng,
        'email': ?email,
        if (includeDefault && isDefault) 'is_default': true,
      };

  Address copyWith({
    String? id,
    String? label,
    String? name,
    String? phone,
    String? city,
    String? district,
    String? addressLine,
    String? building,
    String? floor,
    String? apartment,
    double? lat,
    double? lng,
    String? email,
    bool? isDefault,
    bool? serves,
    String? servesReason,
  }) =>
      Address(
        id: id ?? this.id,
        label: label ?? this.label,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        district: district ?? this.district,
        addressLine: addressLine ?? this.addressLine,
        building: building ?? this.building,
        floor: floor ?? this.floor,
        apartment: apartment ?? this.apartment,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        email: email ?? this.email,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt,
        serves: serves ?? this.serves,
        servesReason: servesReason ?? this.servesReason,
      );

  static List<Address> listFrom(dynamic value) {
    final raw = value is List ? value : asMap(value)['addresses'];
    return asMapList(raw).map(Address.fromJson).toList();
  }
}
