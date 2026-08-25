import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../catalog/data/product_models.dart';
import 'account_models.dart';

/// Result of `POST /wishlist/toggle`.
typedef WishlistToggle = ({bool wishlisted, int count});

/// Result of a create/update on the address book: the entry that was written,
/// plus the whole book as the server now holds it.
typedef AddressWrite = ({Address address, List<Address> addresses});

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

  /// Every address route answers with the whole book, so the app never has to
  /// splice a local list and can't drift out of step with the server's rule
  /// that exactly one entry is the default.
  Future<List<Address>> addresses() async =>
      Address.listFrom(await _api.get('/addresses'));

  /// Returns `(saved, book)`: the entry that was written — its server-issued
  /// uuid is what checkout sends — alongside the refreshed list.
  Future<AddressWrite> createAddress(Address address) async {
    final data = asMap(
      await _api.post('/addresses', body: address.toJson(includeDefault: true)),
    );
    return (
      address: Address.fromJson(asMap(data['address'])),
      addresses: Address.listFrom(data),
    );
  }

  Future<AddressWrite> updateAddress(String id, Address address) async {
    final data = asMap(
      await _api.patch('/addresses/$id', body: address.toJson(includeDefault: true)),
    );
    return (
      address: Address.fromJson(asMap(data['address'])),
      addresses: Address.listFrom(data),
    );
  }

  Future<List<Address>> deleteAddress(String id) async =>
      Address.listFrom(await _api.delete('/addresses/$id'));

  Future<List<Address>> setDefaultAddress(String id) async =>
      Address.listFrom(await _api.post('/addresses/$id/default'));
}

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(apiClientProvider)));

/// "اطلبها مجددًا" — the products this customer has actually bought before.
/// Guests have no history, so the provider resolves empty instead of firing a
/// call that would 401.
final buyAgainProvider = FutureProvider.autoDispose<List<ProductCard>>((ref) {
  if (!ref.watch(sessionProvider).isAuthenticated) {
    return Future.value(const <ProductCard>[]);
  }
  return ref.watch(accountRepositoryProvider).buyAgain();
});
