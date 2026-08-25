import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import 'catalog_models.dart';
import 'product_models.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<HomePayload> home() async =>
      HomePayload.fromJson(asMap(await _api.get('/home')));

  Future<List<CategoryNode>> categories({String? parent}) async {
    final data = await _api.get('/catalog/categories', query: {'parent': ?parent});
    return asMapList(asMap(data)['categories']).map(CategoryNode.fromJson).toList();
  }

  Future<ListingResult> products(ListingQuery query, int page) async {
    final data = await _api.get('/catalog/products', query: query.toQueryParameters(page));
    return ListingResult.fromJson(asMap(data));
  }

  Future<ProductDetail> product(int id) async =>
      ProductDetail.fromJson(asMap(await _api.get('/catalog/products/$id')));

  Future<List<SearchSuggestion>> suggest(String query, {CancelToken? cancelToken}) async {
    final data = await _api.get(
      '/catalog/search/suggest',
      query: {'q': query},
      cancelToken: cancelToken,
    );
    return asMapList(asMap(data)['suggestions']).map(SearchSuggestion.fromJson).toList();
  }

  /// Barcode lookup. Returns null for a clean 404 — "no such product" is a
  /// normal scanner outcome, not an error to surface as a red screen.
  Future<ProductCard?> byBarcode(String code) async {
    try {
      final data = await _api.get('/catalog/barcode/${Uri.encodeComponent(code)}');
      // Server wraps the card: { "product": CARD }.
      final map = asMap(asMap(data)['product']);
      return map.isEmpty ? null : ProductCard.fromJson(map);
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.notFound) return null;
      rethrow;
    }
  }

  Future<List<BrandSummary>> brands() async {
    final data = await _api.get('/brands');
    return asMapList(asMap(data)['brands']).map(BrandSummary.fromJson).toList();
  }

  Future<BrandPage> brand(String slug) async =>
      BrandPage.fromJson(slug, asMap(await _api.get('/brands/$slug')));

  Future<ListingResult> clearance(int page) async {
    final data = await _api.get('/clearance', query: {'page': page});
    return ListingResult.fromJson(asMap(data));
  }
}

// ── Providers ──────────────────────────────────────────────────────────
//
// Every catalog read watches `catalogRevisionProvider`, so one bump (language
// switch, delivery-location change) refreshes the whole catalog at once — the
// alternative is a screen quietly showing another city's stock.

final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(apiClientProvider)));

final homeProvider = FutureProvider<HomePayload>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).home();
});

/// `null` argument = top-level categories.
final categoriesProvider =
    FutureProvider.family<List<CategoryNode>, String?>((ref, parent) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).categories(parent: parent);
});

final productProvider =
    FutureProvider.autoDispose.family<ProductDetail, int>((ref, id) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).product(id);
});

/// First page of a listing — used for the facet/sort metadata and the initial
/// render. Subsequent pages are fetched imperatively by the grid.
final listingFirstPageProvider =
    FutureProvider.autoDispose.family<ListingResult, ListingQuery>((ref, query) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).products(query, 1);
});

final brandsProvider = FutureProvider<List<BrandSummary>>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).brands();
});
