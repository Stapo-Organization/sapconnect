import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/mrsool_delivery.dart';
import 'models/zooboxi_order.dart';

/// Zooboxi express-order repository — mirrors the record-return style used by
/// CountingRepository / QualityControlRepository.
class ZooboxiOrdersRepository {
  final ApiClient _api = ApiClient();

  /// Home summary — urgent count + the next few open orders.
  Future<({bool success, int urgentCount, List<ZooboxiOrder> orders, String? error})> getSummary() async {
    final result = await _api.get(ApiEndpoints.zooboxiOrdersSummary);
    if (result.isSuccess) {
      try {
        final List orders = result.data['orders'] ?? [];
        return (
          success: true,
          urgentCount: (result.data['urgent_count'] ?? 0) as int,
          orders: orders.map((e) => ZooboxiOrder.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          error: null,
        );
      } catch (e) {
        return (success: false, urgentCount: 0, orders: <ZooboxiOrder>[], error: 'parse: $e');
      }
    }
    return (success: false, urgentCount: 0, orders: <ZooboxiOrder>[], error: result.errorMessage);
  }

  /// List express orders for the branch. [scope] = 'waiting' (default) | 'done'.
  Future<({bool success, List<ZooboxiOrder> orders, String? error})> getOrders({String? status, String? scope}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (scope != null) params['scope'] = scope;

    final result = await _api.get(ApiEndpoints.zooboxiOrders, queryParams: params.isEmpty ? null : params);
    if (result.isSuccess) {
      try {
        final List items = result.data['data'] ?? [];
        return (success: true, orders: items.map((e) => ZooboxiOrder.fromJson(Map<String, dynamic>.from(e as Map))).toList(), error: null);
      } catch (e) {
        return (success: false, orders: <ZooboxiOrder>[], error: 'parse: $e');
      }
    }
    return (success: false, orders: <ZooboxiOrder>[], error: result.errorMessage);
  }

  Future<({bool success, ZooboxiOrder? order, String? error})> getOrder(int id) async {
    final result = await _api.get(ApiEndpoints.zooboxiOrder(id));
    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (success: true, order: ZooboxiOrder.fromJson(Map<String, dynamic>.from(data as Map)), error: null);
    }
    return (success: false, order: null, error: result.errorMessage);
  }

  /// Begin preparing (pending → preparing).
  Future<({bool success, ZooboxiOrder? order, String? error})> startPreparing(int id) async {
    final result = await _api.post(ApiEndpoints.zooboxiOrderStart(id));
    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (success: true, order: ZooboxiOrder.fromJson(Map<String, dynamic>.from(data as Map)), error: null);
    }
    return (success: false, order: null, error: result.errorMessage);
  }

  /// Mark prepared (→ ready) and push the status to WooCommerce.
  /// [wooSynced] reports whether the store status was updated.
  Future<({bool success, bool wooSynced, ZooboxiOrder? order, String? error})> markPrepared(int id) async {
    final result = await _api.post(ApiEndpoints.zooboxiOrderPrepare(id));
    if (result.isSuccess) {
      final data = result.data['data'];
      return (
        success: true,
        wooSynced: result.data['woo_synced'] == true,
        order: data != null ? ZooboxiOrder.fromJson(Map<String, dynamic>.from(data as Map)) : null,
        error: null,
      );
    }
    return (success: false, wooSynced: false, order: null, error: result.errorMessage);
  }

  // ─── Mrsool (مرسول) express last-mile ──────────────────────

  /// Eligibility + the current (or last) courier request for this order.
  Future<({bool success, bool eligible, String? reason, MrsoolDelivery? delivery, String? error})>
      getMrsool(int id) async {
    final result = await _api.get(ApiEndpoints.zooboxiOrderMrsool(id));
    if (result.isSuccess) {
      try {
        final eligible = (result.data['eligible'] as Map?) ?? const {};
        return (
          success: true,
          eligible: eligible['ok'] == true,
          reason: eligible['reason']?.toString(),
          delivery: _delivery(result.data['delivery']),
          error: null,
        );
      } catch (e) {
        return (success: false, eligible: false, reason: null, delivery: null, error: 'parse: $e');
      }
    }
    return (success: false, eligible: false, reason: null, delivery: null, error: result.errorMessage);
  }

  /// Indicative courier price. [price] is null when Mrsool cannot quote.
  Future<({bool success, double? price, String? error})> getMrsoolQuote(int id) async {
    final result = await _api.get(ApiEndpoints.zooboxiOrderMrsoolQuote(id));
    if (result.isSuccess) {
      final raw = result.data['price'];
      final price = raw == null ? null : (raw is num ? raw.toDouble() : double.tryParse('$raw'));
      return (success: true, price: price, error: null);
    }
    return (success: false, price: null, error: result.errorMessage);
  }

  /// Ask Mrsool for a courier (manual, branch-triggered).
  Future<({bool success, MrsoolDelivery? delivery, String? error})> requestMrsool(int id) async {
    final result = await _api.post(ApiEndpoints.zooboxiOrderMrsoolRequest(id));
    if (result.isSuccess) {
      return (success: true, delivery: _delivery(result.data['delivery']), error: null);
    }
    return (success: false, delivery: null, error: result.errorMessage);
  }

  /// Cancel a courier request that has not been picked up yet.
  Future<({bool success, MrsoolDelivery? delivery, String? error})> cancelMrsool(int id) async {
    final result = await _api.post(ApiEndpoints.zooboxiOrderMrsoolCancel(id));
    if (result.isSuccess) {
      return (success: true, delivery: _delivery(result.data['delivery']), error: null);
    }
    return (success: false, delivery: null, error: result.errorMessage);
  }

  MrsoolDelivery? _delivery(dynamic raw) =>
      raw is Map ? MrsoolDelivery.fromJson(Map<String, dynamic>.from(raw)) : null;
}
