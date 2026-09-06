import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/bundle.dart';

/// «حزم زوبوكسي» repository (owner only) — record-return style, mirroring
/// PromotionsRepository.
class BundlesRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, int pendingCount, int liveCount, String? error})> getSummary() async {
    final result = await _api.get(ApiEndpoints.bundlesSummary);
    if (result.isSuccess) {
      return (
        success: true,
        pendingCount: (result.data['pending_count'] ?? 0) as int,
        liveCount: (result.data['live_count'] ?? 0) as int,
        error: null,
      );
    }
    return (success: false, pendingCount: 0, liveCount: 0, error: result.errorMessage);
  }

  /// List bundles by [status]: suggested | live | history.
  Future<({bool success, List<Bundle> bundles, String? error})> getBundles({String status = 'suggested'}) async {
    final result = await _api.get(ApiEndpoints.bundles, queryParams: {'status': status});
    if (result.isSuccess) {
      try {
        final List items = result.data['bundles'] ?? [];
        return (
          success: true,
          bundles: items.map((e) => Bundle.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          error: null,
        );
      } catch (e) {
        return (success: false, bundles: <Bundle>[], error: 'parse: $e');
      }
    }
    return (success: false, bundles: <Bundle>[], error: result.errorMessage);
  }

  /// Approve — optionally with an edited name/price. The backend re-guards the
  /// price against the cost floor and savings cap; a 422 message comes back verbatim.
  Future<({bool success, String? error})> approve(int id, {String? nameAr, double? price}) async {
    final result = await _api.post(ApiEndpoints.bundleApprove(id), body: {
      if (nameAr != null && nameAr.isNotEmpty) 'name_ar': nameAr,
      if (price != null) 'bundle_price': price,
    });
    return (success: result.isSuccess, error: result.errorMessage);
  }

  Future<({bool success, String? error})> reject(int id, {String? reason}) async {
    final result = await _api.post(ApiEndpoints.bundleReject(id), body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return (success: result.isSuccess, error: result.errorMessage);
  }

  Future<({bool success, String? error})> retire(int id) async {
    final result = await _api.post(ApiEndpoints.bundleRetire(id));
    return (success: result.isSuccess, error: result.errorMessage);
  }
}
