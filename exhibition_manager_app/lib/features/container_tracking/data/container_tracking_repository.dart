import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/container_models.dart';

/// Data access for Container Tracking — list shipments (filter by state, search,
/// sort) and fetch one shipment's full voyage detail. Pure reads against our
/// local Traqo mirror; never calls Traqo.
class ContainerTrackingRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, ContainerOverview? data, String? error})> getOverview({
    String state = 'all',
    String sort = 'urgency',
    String? search,
  }) async {
    final params = <String, String>{'state': state, 'sort': sort};
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    final result = await _api.get(ApiEndpoints.containerTracking, queryParams: params);
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: ContainerOverview.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  Future<({bool success, ContainerDetail? data, String? error})> getDetail(int id) async {
    final result = await _api.get(ApiEndpoints.containerTrackingDetail(id));
    if (result.isSuccess && result.data is Map) {
      try {
        final m = Map<String, dynamic>.from(result.data as Map);
        final c = Map<String, dynamic>.from(m['container'] as Map? ?? m);
        return (success: true, data: ContainerDetail.fromJson(c), error: null);
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }
}
