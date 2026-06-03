import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
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

  /// List express orders for the branch (un-prepared by default).
  Future<({bool success, List<ZooboxiOrder> orders, String? error})> getOrders({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

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
}
