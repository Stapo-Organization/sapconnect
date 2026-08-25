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
