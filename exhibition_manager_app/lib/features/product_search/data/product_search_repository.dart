import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/product_models.dart';

/// Data access for product search & detail. All read-only.
class ProductSearchRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, List<ProductHit> items, String? error})> search(String query) async {
    final result = await _api.get(ApiEndpoints.productSearch, queryParams: {'q': query});
    if (result.isSuccess && result.data is Map) {
      final raw = ((result.data['items'] as List?) ?? [])
          .map((e) => ProductHit.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return (success: true, items: raw, error: null);
    }
    return (success: false, items: <ProductHit>[], error: result.errorMessage);
  }

  Future<({bool success, ProductDetail? data, String? error})> detail(
    String itemCode, {
    List<String> branches = const [],
  }) async {
    final result = await _api.get(
      ApiEndpoints.productDetail(itemCode),
      queryParams: branches.isEmpty ? null : {'branches': branches.join(',')},
    );
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: ProductDetail.fromJson(Map<String, dynamic>.from(result.data as Map)),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }
}
