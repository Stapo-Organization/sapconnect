import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import 'cart_models.dart';

/// Every cart route answers with the *whole* cart, so one shape covers reads
/// and writes and the client never has to reconcile a partial update.
class CartRepository {
  CartRepository(this._api);

  final ApiClient _api;

  Future<CartData> fetch() async => CartData.fromJson(asMap(await _api.get('/cart')));

  Future<CartData> addItem({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async {
    final data = await _api.post('/cart/items', body: {
      'product_id': productId,
      'variation_id': ?variationId,
      'quantity': quantity,
      if (attributes != null && attributes.isNotEmpty) 'attributes': attributes,
    });
    return CartData.fromJson(asMap(data));
  }

  /// Moves to the other storefront's basket. The one being left is stashed
  /// server-side and comes back whole on the next switch, so this is a swap,
  /// not a discard.
  Future<CartData> switchBasket(String shelf) async {
    final data = await _api.post('/cart/basket', body: {'shelf': shelf});
    return CartData.fromJson(asMap(data));
  }

  /// Puts the basket on whichever shelf this request says it is browsing.
  ///
  /// No shelf is named on purpose: the store aligns to the storefront it is
  /// serving THIS request as, so a closed إكسبريس resolves to زوبكسي by
  /// itself and there is never a target to argue about. It answers with the
  /// cart either way — an alignment with nothing to move is a plain read.
  Future<({CartData cart, BasketMove? move})> alignBasket() async {
    final data = asMap(await _api.post('/cart/basket', body: const {}));
    final cart = CartData.fromJson(data);
    return (cart: cart, move: BasketMove.maybe(data['switched'], notices: cart.notices));
  }

  Future<CartData> setQuantity(String key, int quantity) async {
    final data = await _api.patch('/cart/items/$key', body: {'quantity': quantity});
    return CartData.fromJson(asMap(data));
  }

  Future<CartData> removeItem(String key) async =>
      CartData.fromJson(asMap(await _api.delete('/cart/items/$key')));

  Future<CartData> applyCoupon(String code) async =>
      CartData.fromJson(asMap(await _api.post('/cart/coupon', body: {'code': code})));

  Future<CartData> removeCoupon(String code) async =>
      CartData.fromJson(asMap(await _api.delete('/cart/coupon/$code')));
}

final cartRepositoryProvider =
    Provider<CartRepository>((ref) => CartRepository(ref.watch(apiClientProvider)));
