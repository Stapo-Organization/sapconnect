import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/distribution_models.dart';

/// Data access for Smart Stock Distribution — list suggestions, poll engine
/// status, and trigger a re-run.
class StockDistributionRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, DistributionOverview? data, String? error})> getSuggestions({String? transferType}) async {
    final params = <String, String>{};
    if (transferType != null) params['transfer_type'] = transferType;
    final result = await _api.get(ApiEndpoints.stockDistribution, queryParams: params.isEmpty ? null : params);
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: DistributionOverview.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  Future<({bool success, DistributionStatus? status, String? error})> getStatus() async {
    final result = await _api.get(ApiEndpoints.stockDistributionStatus);
    if (result.isSuccess && result.data is Map) {
      return (success: true, status: DistributionStatus.fromJson(Map<String, dynamic>.from(result.data as Map)), error: null);
    }
    return (success: false, status: null, error: result.errorMessage);
  }

  Future<({bool success, bool started, String? message, String? error})> run() async {
    final result = await _api.post(ApiEndpoints.stockDistributionRun);
    if (result.isSuccess && result.data is Map) {
      final m = Map<String, dynamic>.from(result.data as Map);
      return (success: true, started: m['started'] == true, message: m['message']?.toString(), error: null);
    }
    // 409 (already running) still carries a message worth surfacing.
    final msg = result.data is Map ? (result.data['message']?.toString()) : null;
    return (success: false, started: false, message: msg, error: result.errorMessage);
  }
}
