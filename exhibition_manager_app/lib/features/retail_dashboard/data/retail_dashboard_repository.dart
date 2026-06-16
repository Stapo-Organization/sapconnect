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
  }) async {
    final params = <String, String>{'period': period, 'sort': sort};
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
}
