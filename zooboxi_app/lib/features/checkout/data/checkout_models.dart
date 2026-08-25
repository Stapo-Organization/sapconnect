import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import '../../account/data/account_models.dart';
import '../../cart/data/cart_models.dart';

/// A payment method offered for this basket. `id` is opaque to the app — it
/// goes straight back on `POST /checkout` — so the server can add or retire
/// gateways without a release.
@immutable
class PaymentMethod {
  const PaymentMethod({required this.id, required this.label, this.sub});

  final String id;
  final String label;

  /// Supporting line, e.g. "مدى · Apple Pay · بطاقات".
  final String? sub;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: asString(json['id']),
        label: asString(json['label']),
        sub: asStringOrNull(json['sub']),
      );
}

/// `GET /checkout` — the review screen's payload.
@immutable
class CheckoutReview {
  const CheckoutReview({
    this.shipments = const [],
    this.totals = const CartTotals(),
    this.paymentMethods = const [],
    this.addresses = const [],
  });

  final List<Shipment> shipments;
  final CartTotals totals;
  final List<PaymentMethod> paymentMethods;
  final List<Address> addresses;

  Address? get defaultAddress {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  factory CheckoutReview.fromJson(Map<String, dynamic> json) => CheckoutReview(
        shipments: asMapList(json['shipments']).map(Shipment.fromJson).toList(),
        totals: CartTotals.fromJson(asMap(json['totals'])),
        paymentMethods: asMapList(json['payment_methods']).map(PaymentMethod.fromJson).toList(),
        addresses: asMapList(json['addresses']).map(Address.fromJson).toList(),
      );
}

/// `POST /checkout` — the order exists now. [orderKey] is what lets an
/// unauthenticated buyer return to pay for it.
@immutable
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.orderKey,
    required this.status,
    this.total = 0,
    this.paymentRequired = false,
  });

  final int orderId;
  final String orderNumber;
  final String orderKey;
  final String status;
  final double total;

  /// False for cash on delivery — the success screen is the end of the flow.
  final bool paymentRequired;

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        orderId: asInt(json['order_id']),
        orderNumber: asString(json['order_number']),
        orderKey: asString(json['order_key']),
        status: asString(json['status']),
        total: asDouble(json['total']),
        paymentRequired: asBool(json['payment_required']),
      );
}
