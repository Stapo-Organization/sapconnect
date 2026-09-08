import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// Where the courier actually is — the payload behind the live map.
///
/// This is deliberately its own model rather than a field on `OrderTracking`:
/// a tracking *number* is a static fact printed once, while this is a moving
/// thing the screen re-fetches every few seconds and stops watching the moment
/// the courier is done.

/// Our own lifecycle, mirrored from the backend so the UI never has to reason
/// about Mrsool's fourteen raw statuses.
enum LivePhase {
  searching,
  assigned,
  inTransit,
  delivered,
  failed;

  static LivePhase parse(String? raw) => switch (raw) {
        'assigned' => LivePhase.assigned,
        'in_transit' => LivePhase.inTransit,
        'delivered' => LivePhase.delivered,
        'failed' => LivePhase.failed,
        _ => LivePhase.searching,
      };

  bool get isTerminal => this == LivePhase.delivered || this == LivePhase.failed;
}

@immutable
class LiveCourier {
  const LiveCourier({this.name, this.phone, this.lat, this.lng});

  final String? name;
  final String? phone;
  final double? lat;
  final double? lng;

  bool get hasPosition =>
      lat != null && lng != null && (lat!.abs() > 0.01 || lng!.abs() > 0.01);
  bool get isKnown => (name ?? '').isNotEmpty;

  factory LiveCourier.fromJson(Map<String, dynamic> json) => LiveCourier(
        name: asStringOrNull(json['name']),
        phone: asStringOrNull(json['phone']),
        lat: asDoubleOrNull(json['lat']),
        lng: asDoubleOrNull(json['lng']),
      );
}

@immutable
class LivePoint {
  const LivePoint({required this.lat, required this.lng, this.label});

  final double lat;
  final double lng;
  final String? label;

  static LivePoint? maybe(dynamic value) {
    final map = asMap(value);
    final lat = asDoubleOrNull(map['lat']);
    final lng = asDoubleOrNull(map['lng']);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LivePoint(lat: lat, lng: lng, label: asStringOrNull(map['label']));
  }
}

@immutable
class LiveStep {
  const LiveStep({required this.key, required this.label, this.at, this.done = false});

  final String key;

  /// The server's Arabic wording. Only a fallback — the screen localizes [key]
  /// itself, so an English reader gets English.
  final String label;
  final DateTime? at;
  final bool done;

  factory LiveStep.fromJson(Map<String, dynamic> json) => LiveStep(
        key: asString(json['key']),
        label: asString(json['label']),
        at: asDate(json['at']),
        done: asBool(json['done']),
      );
}

@immutable
class LiveTracking {
  const LiveTracking({
    required this.phase,
    this.active = false,
    this.status,
    this.statusLabel,
    this.carrierLabel,
    this.number,
    this.isPartial = false,
    this.courier = const LiveCourier(),
    this.pickup,
    this.dropoff,
    this.distanceKm,
    this.etaMinutes,
    this.headingTo,
    this.steps = const [],
    this.proofImages = const [],
    this.trackingUrl,
    this.requestedAt,
    this.deliveredAt,
    this.updatedAt,
  });

  final LivePhase phase;

  /// True while the courier is still carrying the order. The backend blanks his
  /// name and number once he is done — nobody needs a stranger's phone number
  /// sitting in their order history forever.
  final bool active;

  /// Mrsool's raw status, e.g. `DELIVERING`. The screen maps it to a localized
  /// sentence; [statusLabel] is the Arabic fallback the server already wrote.
  final String? status;
  final String? statusLabel;
  final String? carrierLabel;
  final String? number;
  final bool isPartial;

  final LiveCourier courier;
  final LivePoint? pickup;
  final LivePoint? dropoff;

  /// Straight-line courier → door. Null until he is carrying the order: before
  /// pickup he is riding the other way, toward the branch.
  final double? distanceKm;
  final int? etaMinutes;

  /// Which leg the courier is on — `pickup` (heading to the branch), `dropoff`
  /// (heading to you), or null when he is not riding for us yet.
  final String? headingTo;

  final List<LiveStep> steps;
  final List<String> proofImages;
  final String? trackingUrl;

  final DateTime? requestedAt;
  final DateTime? deliveredAt;
  final DateTime? updatedAt;

  /// Whether the screen should keep polling.
  bool get isLive => !phase.isTerminal;

  /// The map is only worth drawing once there is something moving on it.
  bool get hasMap => courier.hasPosition && dropoff != null;

  static LiveTracking? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty || map['phase'] == null) return null;
    return LiveTracking.fromJson(map);
  }

  factory LiveTracking.fromJson(Map<String, dynamic> json) => LiveTracking(
        phase: LivePhase.parse(asStringOrNull(json['phase'])),
        active: asBool(json['active']),
        status: asStringOrNull(json['status']),
        statusLabel: asStringOrNull(json['status_label']),
        carrierLabel: asStringOrNull(json['carrier_label']),
        number: asStringOrNull(json['number']),
        isPartial: asBool(json['is_partial']),
        courier: LiveCourier.fromJson(asMap(json['courier'])),
        pickup: LivePoint.maybe(json['pickup']),
        dropoff: LivePoint.maybe(json['dropoff']),
        distanceKm: asDoubleOrNull(json['distance_km']),
        etaMinutes: asIntOrNull(json['eta_minutes']),
        headingTo: asStringOrNull(json['heading_to']),
        steps: asMapList(json['steps']).map(LiveStep.fromJson).toList(),
        proofImages: asStringList(json['proof_images']),
        trackingUrl: asStringOrNull(json['tracking_url']),
        requestedAt: asDate(json['requested_at']),
        deliveredAt: asDate(json['delivered_at']),
        updatedAt: asDate(json['updated_at']),
      );
}
