import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/stock_transfer.dart';

/// Stock Transfer repository
class StockTransferRepository {
  final ApiClient _api = ApiClient();

  /// List stock transfers with optional filters
  Future<({bool success, List<StockTransfer> transfers, String? error})> getTransfers({
    String? status,
    String? internalStatus,
    bool hideCompleted = true,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null) params['status'] = status;
    if (internalStatus != null) params['internal_status'] = internalStatus;
    if (hideCompleted) params['hide_completed'] = '1';

    final result = await _api.get(ApiEndpoints.stockTransfers, queryParams: params);

    if (result.isSuccess) {
      final List items = result.data['data'] ?? [];
      final transfers = items.map((e) => StockTransfer.fromJson(e)).toList();
      return (success: true, transfers: transfers, error: null);
    }

    return (success: false, transfers: <StockTransfer>[], error: result.errorMessage);
  }

  /// Get single transfer details
  Future<({bool success, StockTransfer? transfer, String? error})> getTransfer(int id) async {
    final result = await _api.get(ApiEndpoints.stockTransfer(id));

    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (success: true, transfer: StockTransfer.fromJson(data), error: null);
    }

    return (success: false, transfer: null, error: result.errorMessage);
  }

  /// Send items (update sent quantities)
  Future<({bool success, String? error})> sendItems(
      int id, List<Map<String, dynamic>> items, {String? notes}) async {
    final result = await _api.post(ApiEndpoints.sendItems(id), body: {
      'items': items,
      if (notes != null) 'notes': notes,
    });

    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Confirm send
  Future<({bool success, String? error})> confirmSend(int id) async {
    final result = await _api.post(ApiEndpoints.confirmSend(id));
    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Receive items (update received quantities)
  Future<({bool success, String? error})> receiveItems(
      int id, List<Map<String, dynamic>> items, {String? notes}) async {
    final result = await _api.post(ApiEndpoints.receiveItems(id), body: {
      'items': items,
      if (notes != null) 'notes': notes,
    });

    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Confirm receive
  Future<({bool success, String? error})> confirmReceive(int id) async {
    final result = await _api.post(ApiEndpoints.confirmReceive(id));
    return (success: result.isSuccess, error: result.errorMessage);
  }
}
