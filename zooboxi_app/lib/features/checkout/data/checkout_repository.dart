import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../account/data/account_models.dart';
import '../../cart/data/cart_models.dart';
import 'checkout_models.dart';

/// Server error codes this flow reacts to structurally rather than by just
/// printing the message.
abstract final class CheckoutErrors {
  /// The basket changed when it was re-priced at the delivery address — the
  /// customer must see what changed before any money moves.
  static const cartChanged = 'cart_changed';
  static const cartEmpty = 'cart_empty';
  static const gatewayUnavailable = 'gateway_unavailable';
  static const alreadyPaid = 'already_paid';

  /// Address problems the address step can highlight in place.
  static const addressCodes = {
    'name_required',
    'phone_invalid',
    'coordinates_required',
    'address_line_required',
    'city_required',
    'address_required',
    'address_requires_login',
    'address_not_found',
  };
}

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

/// The fresh cart a `cart_changed` refusal carried, or null for any other
/// failure. Reading it here keeps the "what changed?" logic out of the widget.
CartData? cartFromChangedError(Object? error) {
  if (error is! ApiException || error.code != CheckoutErrors.cartChanged) return null;
  final cart = asMap(error.data)['cart'];
  final map = asMap(cart);
  return map.isEmpty ? null : CartData.fromJson(map);
}

final checkoutRepositoryProvider =
    Provider<CheckoutRepository>((ref) => CheckoutRepository(ref.watch(apiClientProvider)));

final checkoutReviewProvider = FutureProvider.autoDispose<CheckoutReview>(
  (ref) => ref.watch(checkoutRepositoryProvider).review(),
);
