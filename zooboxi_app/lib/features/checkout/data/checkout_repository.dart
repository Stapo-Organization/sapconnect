import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../account/data/account_models.dart';
import 'checkout_models.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);

  final ApiClient _api;

  Future<CheckoutReview> review() async =>
      CheckoutReview.fromJson(asMap(await _api.get('/checkout')));

  /// Places the order. Exactly one of [addressId] / [address] is sent — the
  /// server re-seeds the delivery location from that address's coordinates
  /// before it prices the shipments, so the promise matches the destination
  /// rather than wherever the phone happens to be standing.
  Future<PlacedOrder> place({
    String? addressId,
    Address? address,
    bool saveAddress = false,
    required String paymentMethod,
    String? notes,
  }) async {
    assert(addressId != null || address != null, 'checkout needs an address');
    final data = await _api.post('/checkout', body: {
      'address_id': ?addressId,
      if (address != null) 'address': {...address.toJson(), 'save': saveAddress},
      'payment_method': paymentMethod,
      'notes': ?notes,
    });
    return PlacedOrder.fromJson(asMap(data));
  }
}

final checkoutRepositoryProvider =
    Provider<CheckoutRepository>((ref) => CheckoutRepository(ref.watch(apiClientProvider)));

final checkoutReviewProvider = FutureProvider.autoDispose<CheckoutReview>(
  (ref) => ref.watch(checkoutRepositoryProvider).review(),
);
