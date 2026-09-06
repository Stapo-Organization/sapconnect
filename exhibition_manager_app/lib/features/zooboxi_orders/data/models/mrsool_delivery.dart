// Models for the Mrsool (مرسول) express last-mile leg of a Zooboxi order
// (GET/POST /zooboxi-orders/{id}/mrsool*).
//
// Every field is parsed defensively — the backend omits nulls and the Mrsool
// payload itself is only partially populated until a courier is assigned.

import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/date_names.dart';

/// Mrsool delivery phases (backend-mapped, the single source of truth).
class MrsoolPhase {
  MrsoolPhase._();

  static const String searching = 'searching';
  static const String assigned = 'assigned';
  static const String inTransit = 'in_transit';
  static const String delivered = 'delivered';
  static const String failed = 'failed';
}

/// The courier assigned to a delivery (empty until Mrsool assigns one).
class MrsoolCourier {
  final String? name;
  final String? phone;
  final double? latitude;
  final double? longitude;

  const MrsoolCourier({this.name, this.phone, this.latitude, this.longitude});

  static MrsoolCourier? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final courier = MrsoolCourier(
      name: _str(json['name']),
      phone: _str(json['phone']),
      latitude: _nullableDouble(json['lat'] ?? json['latitude']),
      longitude: _nullableDouble(json['lng'] ?? json['longitude']),
    );
    return courier.isEmpty ? null : courier;
  }

  bool get isEmpty => name == null && phone == null && latitude == null && longitude == null;
  bool get hasName => name != null && name!.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
}

/// One entry of the Mrsool `events_history`.
class MrsoolEvent {
  final String event;
  final String? label;
  final DateTime? at;

  const MrsoolEvent({required this.event, this.label, this.at});

  factory MrsoolEvent.fromJson(Map<String, dynamic> json) => MrsoolEvent(
        event: _str(json['event']) ?? '',
        label: _str(json['label']),
        at: _date(json['at'] ?? json['created_at']),
      );

  /// Prefer the app's own translation of the status, then the server label.
  String get displayLabel {
    final key = mrsoolStatusKey(event);
    if (key != null) return AppLocalizations.translate(key);
    if (label != null && label!.isNotEmpty) return label!;
    return event;
  }
}

/// One courier request (one row of `mrsool_deliveries`).
class MrsoolDelivery {
  final int id;
  final int? mrsoolOrderId;
  final String? status; // raw Mrsool status string
  final String? statusLabel; // server-provided Arabic label (fallback)
  final String phase;
  final bool isPartial;
  final double? priceQuote;
  final MrsoolCourier? courier;
  final List<MrsoolEvent> events;
  final List<String> pickupImages;
  final List<String> dropoffImages;
  final String? awbUrl;
  final String? lastError;
  final DateTime? requestedAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final DateTime? lastSyncedAt;
  final bool canCancel;

  const MrsoolDelivery({
    required this.id,
    this.mrsoolOrderId,
    this.status,
    this.statusLabel,
    this.phase = MrsoolPhase.searching,
    this.isPartial = false,
    this.priceQuote,
    this.courier,
    this.events = const [],
    this.pickupImages = const [],
    this.dropoffImages = const [],
    this.awbUrl,
    this.lastError,
    this.requestedAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.failedAt,
    this.lastSyncedAt,
    this.canCancel = false,
  });

  factory MrsoolDelivery.fromJson(Map<String, dynamic> json) => MrsoolDelivery(
        id: _int(json['id']),
        mrsoolOrderId: json['mrsool_order_id'] == null ? null : _int(json['mrsool_order_id']),
        status: _str(json['status']),
        statusLabel: _str(json['status_label']),
        phase: _str(json['phase']) ?? MrsoolPhase.searching,
        isPartial: json['is_partial'] == true,
        priceQuote: _nullableDouble(json['price_quote']),
        courier: MrsoolCourier.fromJson(_map(json['courier'])),
        events: _list(json['events'])
            .map((e) => MrsoolEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        pickupImages: _strings(json['pickup_images']),
        dropoffImages: _strings(json['dropoff_images']),
        awbUrl: _str(json['awb_url']),
        lastError: _str(json['last_error']),
        requestedAt: _date(json['requested_at']),
        assignedAt: _date(json['assigned_at']),
        pickedUpAt: _date(json['picked_up_at']),
        deliveredAt: _date(json['delivered_at']),
        failedAt: _date(json['failed_at']),
        lastSyncedAt: _date(json['last_synced_at']),
        canCancel: json['can_cancel'] == true,
      );

  bool get isSearching => phase == MrsoolPhase.searching;
  bool get isAssigned => phase == MrsoolPhase.assigned;
  bool get isInTransit => phase == MrsoolPhase.inTransit;
  bool get isDelivered => phase == MrsoolPhase.delivered;
  bool get isFailed => phase == MrsoolPhase.failed;

  /// No further updates will ever arrive — stops the auto-refresh timer.
  bool get isTerminal => isDelivered || isFailed;

  /// Localized status headline: our own 14-status map, then the server label.
  String get displayStatus {
    final key = mrsoolStatusKey(status);
    if (key != null) return AppLocalizations.translate(key);
    if (statusLabel != null && statusLabel!.isNotEmpty) return statusLabel!;
    return AppLocalizations.translate(_phaseKey);
  }

  String get _phaseKey => switch (phase) {
        MrsoolPhase.assigned => 'mrsool_status_courier_assigned',
        MrsoolPhase.inTransit => 'mrsool_status_delivering',
        MrsoolPhase.delivered => 'mrsool_status_delivered',
        MrsoolPhase.failed => 'mrsool_failed',
        _ => 'mrsool_status_courier_pending',
      };

  /// The most meaningful timestamp for the current phase.
  DateTime? get phaseAt => switch (phase) {
        MrsoolPhase.delivered => deliveredAt ?? lastSyncedAt,
        MrsoolPhase.failed => failedAt ?? lastSyncedAt,
        MrsoolPhase.inTransit => pickedUpAt ?? assignedAt,
        MrsoolPhase.assigned => assignedAt,
        _ => requestedAt,
      };

  List<String> get allPhotos => [...pickupImages, ...dropoffImages];
}

/// Translation key for one of the 14 Mrsool statuses (null when unknown).
String? mrsoolStatusKey(String? status) {
  if (status == null || status.isEmpty) return null;
  const known = {
    'COURIER_PENDING',
    'COURIER_ASSIGNED',
    'COURIER_REASSIGNED',
    'PICKUP_ARRIVED',
    'COLLECTING',
    'CONFIRMED_PICKUP',
    'WAITING_FOR_DELIVERY',
    'DELIVERING',
    'DROPOFF_ARRIVED',
    'PARTIALLY_DELIVERED',
    'DELIVERED',
    'RETURN',
    'CANCELED',
    'EXPIRED',
  };
  final upper = status.toUpperCase();
  if (!known.contains(upper)) return null;
  return 'mrsool_status_${upper.toLowerCase()}';
}

/// "14:32" today, otherwise "12 يونيو · 14:32" / "12 Jun · 14:32".
String mrsoolTimeLabel(DateTime? value) {
  if (value == null) return '—';
  final d = value.toLocal();
  final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return time;
  return '${d.day} ${monthName(d.month, short: true)} · $time';
}

// ─── Null-safe parsing helpers ────────────────────────────────
String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('$v') ?? 0;
}

double? _nullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _date(dynamic v) {
  final s = _str(v);
  return s == null ? null : DateTime.tryParse(s);
}

Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List _list(dynamic v) => v is List ? v : const [];

List<String> _strings(dynamic v) =>
    _list(v).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
