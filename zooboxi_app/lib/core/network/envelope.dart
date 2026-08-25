import 'api_exception.dart';

/// The `zooboxi/v2` response envelope: `{ok, data, error:{code, message_ar,
/// message_en}}`.
///
/// Every endpoint returns it, so unwrapping happens once here rather than in
/// each repository. A body that is *not* an envelope (a proxy error page, a
/// bare array) is passed through as data — the model layer then fails loudly
/// on a missing field, which is the honest outcome.
abstract final class Envelope {
  /// Returns the `data` payload, or throws [ApiException] when `ok` is false.
  static dynamic unwrap(dynamic body) {
    if (body is! Map) return body;
    final map = Map<String, dynamic>.from(body);
    if (!map.containsKey('ok')) {
      // Not our envelope — some middlebox answered. Hand it back untouched.
      return map.containsKey('data') ? map['data'] : map;
    }
    if (map['ok'] == true) return map['data'];
    throw errorFrom(map, null);
  }

  /// Builds a typed exception from an envelope body plus the HTTP status.
  static ApiException errorFrom(Map<String, dynamic> body, int? status) {
    final error = body['error'];
    String? code;
    String? ar;
    String? en;
    final fields = <String, String>{};

    if (error is Map) {
      code = error['code']?.toString();
      ar = error['message_ar']?.toString();
      en = error['message_en']?.toString();
      final details = error['fields'] ?? error['details'];
      if (details is Map) {
        details.forEach((k, v) {
          final first = v is List && v.isNotEmpty ? v.first : v;
          if (first != null) fields['$k'] = first.toString();
        });
      }
    } else if (error is String) {
      ar = error;
      en = error;
    }

    return ApiException(
      type: typeForStatus(status, code),
      code: code,
      messageAr: ar,
      messageEn: en,
      statusCode: status,
      fieldErrors: fields,
      // Kept, not dropped: a refusal can carry the state that fixes it —
      // `cart_changed` returns the fresh cart the review screen must show.
      data: body['data'],
    );
  }

  static ApiErrorType typeForStatus(int? status, String? code) {
    if (code == 'auth_required' || code == 'invalid_token') {
      return ApiErrorType.unauthorized;
    }
    return switch (status) {
      401 => ApiErrorType.unauthorized,
      403 => ApiErrorType.forbidden,
      404 => ApiErrorType.notFound,
      400 || 422 => ApiErrorType.validation,
      429 => ApiErrorType.server,
      != null && >= 500 => ApiErrorType.server,
      _ => ApiErrorType.unknown,
    };
  }
}

// ── JSON coercion helpers ──────────────────────────────────────────────
//
// The store is WordPress: a number can arrive as `12`, `"12"`, `"12.50"` or
// `""`, and a list can arrive as `null`. Models coerce through these instead
// of casting, so one loose field never blanks a whole screen.

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

List<String> asStringList(dynamic v) =>
    v is List ? v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : const [];

String asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double asDouble(dynamic v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', ''));
  }
  return null;
}

int asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? asDouble(v, fallback: fallback.toDouble()).round();
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }
  return null;
}

/// WordPress serializes booleans as `true`, `1`, `"1"`, `"yes"` and `"true"`.
bool asBool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return fallback;
    return s == '1' || s == 'true' || s == 'yes' || s == 'on';
  }
  return fallback;
}

DateTime? asDate(dynamic v) {
  final s = asStringOrNull(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}
