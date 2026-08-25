import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../catalog/data/product_models.dart';
import 'account_models.dart';

/// Result of `POST /wishlist/toggle`.
typedef WishlistToggle = ({bool wishlisted, int count});

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<List<ProductCard>> wishlist() async =>
      ProductCard.listFrom(asMap(await _api.get('/wishlist'))['products']);

  Future<WishlistToggle> toggleWishlist(int productId) async {
    final data = asMap(await _api.post('/wishlist/toggle', body: {'product_id': productId}));
    return (wishlisted: asBool(data['wishlisted']), count: asInt(data['count']));
  }

  Future<List<ProductCard>> buyAgain() async =>
      ProductCard.listFrom(asMap(await _api.get('/account/buy-again'))['products']);

  /// The contract shows a bare `[ADDR]`; some builds wrap it as
  /// `{addresses: […]}`. Accept either rather than break on a shape change.
  Future<List<Address>> addresses() async {
    final data = await _api.get('/addresses');
    final raw = data is List ? data : asMap(data)['addresses'];
    return asMapList(raw).map(Address.fromJson).toList();
  }

  Future<Address> createAddress(Address address) async =>
      Address.fromJson(asMap(await _api.post('/addresses', body: address.toJson())));

  Future<Address> updateAddress(String id, Address address) async =>
      Address.fromJson(asMap(await _api.patch('/addresses/$id', body: address.toJson())));

  Future<void> deleteAddress(String id) => _api.delete('/addresses/$id');

  Future<void> setDefaultAddress(String id) => _api.post('/addresses/$id/default');
}

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(apiClientProvider)));
