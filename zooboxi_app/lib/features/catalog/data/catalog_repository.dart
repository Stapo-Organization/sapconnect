import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/storage/local_store.dart';
import 'catalog_models.dart';
import 'product_models.dart';

class CatalogRepository {
  CatalogRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// The storefront. The raw body is kept on disk so the *next* cold start
  /// paints a real page instead of a shimmer — see [cachedHome].
  Future<HomePayload> home() async {
    final data = asMap(await _api.get('/home'));
    // Fire-and-forget: a disk write must never delay the first frame.
    unawaited(_store.setHomeCache(data));
    return HomePayload.fromJson(data);
  }

  /// Last good `/home` body, decoded. Null on a first run or after a
  /// location change (which drops it — it described another city).
  HomePayload? cachedHome() {
    final json = _store.homeCache;
    if (json == null) return null;
    try {
      final payload = HomePayload.fromJson(json);
      return payload.isEmpty ? null : payload;
    } catch (_) {
      return null;
    }
  }

  /// `GET /home/feed` — the personal half of the page. [recentIds] are the
  /// products this device has looked at, which is the only signal a guest has.
  Future<HomeFeed> homeFeed(List<int> recentIds, {required bool authed}) async {
    final data = asMap(await _api.get(
      '/home/feed',
      query: {if (recentIds.isNotEmpty) 'recent_ids': recentIds.join(',')},
    ));
    unawaited(_store.setHomeFeedCache(data, authed: authed));
    return HomeFeed.fromJson(data);
  }

  /// Last good feed body — but only when it was captured in the *current*
  /// sign-in state, so a previous account's history can't flash on screen.
  HomeFeed? cachedHomeFeed({required bool authed}) {
    final cached = _store.homeFeedCache;
    if (cached == null || cached.authed != authed) return null;
    try {
      return HomeFeed.fromJson(cached.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<CategoryNode>> categories({String? parent}) async {
    final data = await _api.get('/catalog/categories', query: {'parent': ?parent});
    return asMapList(asMap(data)['categories']).map(CategoryNode.fromJson).toList();
  }

  Future<ListingResult> products(ListingQuery query, int page) async {
    final data = await _api.get('/catalog/products', query: query.toQueryParameters(page));
    return ListingResult.fromJson(asMap(data));
  }

  /// [variationId] re-scopes the delivery promise and warehouse counts to a
  /// chosen pack variation (كرتون = N pieces) — the server divides through.
  Future<ProductDetail> product(int id, {int? variationId}) async =>
      ProductDetail.fromJson(asMap(await _api.get(
        '/catalog/products/$id',
        query: {'variation_id': ?variationId},
      )));

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

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider), ref.watch(localStoreProvider)),
);

final homeProvider = FutureProvider<HomePayload>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).home();
});

/// Yesterday's storefront, read straight off disk.
///
/// Home is the screen people open the app *into*: a shimmer there is the whole
/// first impression. So the last good payload paints on frame one and the
/// network refresh swaps in behind it — and if that refresh fails, the
/// customer keeps a browsable store instead of an error page.
final homeCacheProvider = Provider<HomePayload?>((ref) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).cachedHome();
});

/// `GET /home/feed`. Refetched when the catalog revision bumps (language or
/// city) and whenever the sign-in identity changes — signing in turns "what
/// you were looking at" into "what you actually buy".
final homeFeedProvider = FutureProvider.autoDispose<HomeFeed>((ref) {
  ref.watch(catalogRevisionProvider);
  final session = ref.watch(sessionProvider.select((s) => (s.status, s.user?.id)));
  return ref.watch(catalogRepositoryProvider).homeFeed(
        ref.watch(localStoreProvider).recentlyViewed,
        authed: session.$1 == AuthStatus.authenticated,
      );
});

/// The feed's disk snapshot — same stale-while-revalidate deal as
/// [homeCacheProvider], scoped to the current sign-in state.
final homeFeedCacheProvider = Provider.autoDispose<HomeFeed?>((ref) {
  ref.watch(catalogRevisionProvider);
  final authed = ref.watch(sessionProvider.select((s) => s.isAuthenticated));
  return ref.watch(catalogRepositoryProvider).cachedHomeFeed(authed: authed);
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

/// The variation-scoped read the PDP overlays on top of [productProvider]
/// when a pack is chosen: same payload, delivery + warehouse numbers spoken
/// in that variation's units. Keyed by record so each pack caches separately.
final variationDeliveryProvider = FutureProvider.autoDispose
    .family<ProductDetail, ({int id, int variationId})>((ref, key) {
  ref.watch(catalogRevisionProvider);
  return ref
      .watch(catalogRepositoryProvider)
      .product(key.id, variationId: key.variationId);
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

/// One brand's boutique page, keyed by slug. Auto-disposed: a customer who
/// walks through six brands should not be holding six payloads of hero art.
final brandPageProvider =
    FutureProvider.autoDispose.family<BrandPage, String>((ref, slug) {
  ref.watch(catalogRevisionProvider);
  return ref.watch(catalogRepositoryProvider).brand(slug);
});
