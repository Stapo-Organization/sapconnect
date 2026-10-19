import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/data/cart_models.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/product_models.dart';

/// «تفعيل البراندات» (owner's pick A + C, 2026-09-24): the brand wherever the
/// customer decides — the search that answers with the brand first, a follow
/// that brings its new products, and the cart that knows its lines.

/// What the search box says for a query: the brand it names (if any) above
/// the product suggestions.
@immutable
class SuggestResult {
  const SuggestResult({this.brand, this.suggestions = const []});

  final BrandSummary? brand;
  final List<SearchSuggestion> suggestions;

  bool get isEmpty => brand == null && suggestions.isEmpty;

  factory SuggestResult.fromJson(Map<String, dynamic> json) => SuggestResult(
        brand: BrandSummary.maybe(json['brand']),
        suggestions: asMapList(json['suggestions']).map(SearchSuggestion.fromJson).toList(),
      );
}

/// The cart's brand help for one line.
@immutable
class CartLineHelp {
  const CartLineHelp({this.substitute, this.samePrice = false, this.upgrade, this.upgradeBrand});

  /// The same line from this shelf, when the item itself cannot be sent.
  final ProductCard? substitute;
  final bool samePrice;

  /// The bigger pack of the same thing, when it is honestly cheaper.
  final BrandValue? upgrade;

  /// Whose pack it is — the band wears that brand's colours.
  final BrandSummary? upgradeBrand;

  factory CartLineHelp.fromJson(Map<String, dynamic> json) {
    final sub = asMap(asMap(json['substitute'])['product']);
    final up = asMap(json['upgrade']);
    return CartLineHelp(
      substitute: sub.isEmpty ? null : ProductCard.fromJson(sub),
      samePrice: asBool(asMap(json['substitute'])['same_price']),
      upgrade: up.isEmpty ? null : BrandValue.maybe(up),
      upgradeBrand: BrandSummary.maybe(up['brand']),
    );
  }
}

/// `GET /cart/brand`.
@immutable
class CartBrandHelp {
  const CartBrandHelp({this.lines = const {}, this.brand, this.complete = const []});

  final Map<String, CartLineHelp> lines;

  /// «أكمل من …»: the basket's leading brand and more of it this shelf holds.
  final BrandSummary? brand;
  final List<ProductCard> complete;

  static const empty = CartBrandHelp();

  /// The single best bigger-pack saving in the basket — one band, not one per line.
  ({String key, BrandValue value, BrandSummary? brand})? get bestUpgrade {
    ({String key, BrandValue value, BrandSummary? brand})? best;
    lines.forEach((key, help) {
      final up = help.upgrade;
      if (up == null) return;
      if (best == null || up.saving > best!.value.saving) {
        best = (key: key, value: up, brand: help.upgradeBrand);
      }
    });
    return best;
  }

  factory CartBrandHelp.fromJson(Map<String, dynamic> json) {
    final lines = <String, CartLineHelp>{};
    asMap(json['lines']).forEach((key, value) {
      final help = CartLineHelp.fromJson(asMap(value));
      if (help.substitute != null || help.upgrade != null) lines[key] = help;
    });
    final complete = asMap(json['complete']);
    return CartBrandHelp(
      lines: lines,
      brand: BrandSummary.maybe(complete['brand']),
      complete: ProductCard.listFrom(complete['products']),
    );
  }
}

class BrandActivationRepository {
  BrandActivationRepository(this._api);

  final ApiClient _api;

  Future<SuggestResult> suggest(String query, {CancelToken? cancelToken}) async =>
      SuggestResult.fromJson(asMap(await _api.get(
        '/catalog/search/suggest',
        query: {'q': query},
        cancelToken: cancelToken,
      )));

  Future<List<String>> followed() async =>
      asStringList(asMap(await _api.get('/account/brands'))['following']);

  Future<bool> toggleFollow(String slug, {bool? follow}) async {
    final data = asMap(await _api.post('/account/brands/toggle', body: {
      'slug': slug,
      'follow': ?follow,
    }));
    return asBool(data['following']);
  }

  Future<List<ProductCard>> freshFromFollowed() async =>
      ProductCard.listFrom(asMap(await _api.get('/account/brands/new'))['products']);

  Future<CartBrandHelp> cartHelp() async =>
      CartBrandHelp.fromJson(asMap(await _api.get('/cart/brand')));
}

final brandActivationRepositoryProvider = Provider<BrandActivationRepository>(
  (ref) => BrandActivationRepository(ref.watch(apiClientProvider)),
);

/// The brands this customer follows, by slug. One shared set, like the
/// wishlist hearts: following INABA from search lights the brand page's
/// button too.
class FollowedBrandsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final authed = ref.watch(sessionProvider.select((s) => s.isAuthenticated));
    if (!authed) return const {};
    Future.microtask(load);
    return const {};
  }

  Future<void> load() async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    try {
      state = (await ref.read(brandActivationRepositoryProvider).followed()).toSet();
    } catch (_) {
      // Non-fatal: the buttons keep what the server last said.
    }
  }

  /// Flips at once and reconciles with the server; returns the final state.
  Future<bool> toggle(String slug) async {
    final was = state.contains(slug);
    state = was ? (state.toSet()..remove(slug)) : (state.toSet()..add(slug));
    try {
      final now = await ref.read(brandActivationRepositoryProvider).toggleFollow(slug, follow: !was);
      state = now ? (state.toSet()..add(slug)) : (state.toSet()..remove(slug));
      ref.invalidate(followedFreshProvider);
      return now;
    } catch (_) {
      state = was ? (state.toSet()..add(slug)) : (state.toSet()..remove(slug));
      rethrow;
    }
  }
}

final followedBrandsProvider =
    NotifierProvider<FollowedBrandsController, Set<String>>(FollowedBrandsController.new);

final isFollowingBrandProvider = Provider.family<bool, String>(
  (ref, slug) => ref.watch(followedBrandsProvider).contains(slug),
);

/// «جديد من براندات تتابعها».
final followedFreshProvider = FutureProvider.autoDispose<List<ProductCard>>((ref) async {
  if (!ref.watch(sessionProvider).isAuthenticated) return const [];
  if (ref.watch(followedBrandsProvider).isEmpty) return const [];
  return ref.watch(brandActivationRepositoryProvider).freshFromFollowed();
});

/// The cart's brand help, re-asked only when the basket's contents change —
/// not on every rebuild of the cart screen.
String? _cartSignature(CartData? cart) {
  if (cart == null || cart.items.isEmpty) return null;
  final lines = [for (final i in cart.items) '${i.key}:${i.qty}:${i.maxReachable}']..sort();
  return '${cart.basket.shelf}|${lines.join(',')}';
}

final cartBrandHelpProvider = FutureProvider.autoDispose<CartBrandHelp>((ref) async {
  // A `select` on the cart rather than a separate auto-disposed provider: the
  // intermediate provider was flushed lazily while the cart screen built, and
  // invalidating this one from inside that flush scheduled a rebuild of the
  // provider scope mid-build (a debug assertion on every cart change).
  final signature = ref.watch(cartControllerProvider.select((async) => _cartSignature(async.value)));
  if (signature == null) return CartBrandHelp.empty;
  try {
    return await ref.watch(brandActivationRepositoryProvider).cartHelp();
  } catch (_) {
    // Help, not a gate: a failed lookup leaves the cart exactly as it was.
    return CartBrandHelp.empty;
  }
});
