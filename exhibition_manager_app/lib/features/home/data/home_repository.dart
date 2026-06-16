import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/home_overview.dart';

/// One call behind the smart home dashboard. Replaces the old 6 sequential
/// per-feature requests with a single `/home/overview` fetch.
class HomeRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, HomeOverview? data, String? error})> getOverview() async {
    final result = await _api.get(ApiEndpoints.homeOverview);
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: HomeOverview.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }
}
