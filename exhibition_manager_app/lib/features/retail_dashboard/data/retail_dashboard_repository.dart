import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/retail_models.dart';

/// Data access for the Retail Dashboard — read-only cross-branch aggregation.
class RetailDashboardRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, RetailOverview? data, String? error})> getOverview({
    required String period,
    String? from,
    String? to,
    String sort = 'revenue',
    String? channel, // retail | wholesale | total (null → server default: retail)
  }) async {
    final params = <String, String>{'period': period, 'sort': sort};
    if (channel != null) params['channel'] = channel;
    if (period == 'custom' && from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    final result = await _api.get(ApiEndpoints.retailDashboard, queryParams: params);
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: RetailOverview.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  Future<({bool success, BranchDetail? data, String? error})> getBranch(
    String warehouseCode, {
    required String period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'period': period};
    if (period == 'custom' && from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    final result = await _api.get(ApiEndpoints.retailBranch(warehouseCode), queryParams: params);
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: BranchDetail.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  /// Full section list behind a "view all" page. [type] is bleeding | trapped |
  /// top; only `top` honours the period. Returns the raw item maps so the caller
  /// parses them with the matching model factory.
  Future<({bool success, List<Map<String, dynamic>> items, String? error})> getBranchItems(
    String warehouseCode, {
    required String type,
    String? period,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{'type': type};
    if (period != null) params['period'] = period;
    if (period == 'custom' && from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    final result = await _api.get(ApiEndpoints.retailBranchItems(warehouseCode), queryParams: params);
    if (result.isSuccess && result.data is Map) {
      final list = ((result.data as Map)['items'] as List?) ?? const [];
      return (
        success: true,
        items: list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        error: null,
      );
    }
    return (success: false, items: const <Map<String, dynamic>>[], error: result.errorMessage);
  }
}
