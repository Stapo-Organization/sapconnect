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

  /// True for anything that hands off to a hosted gateway page.
  bool get isOnline => id != 'cod';

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: asString(json['id']),
        label: asString(json['label']),
        sub: asStringOrNull(json['sub']),
      );
}

/// One line of the dated delivery promise, pre-composed by the server.
@immutable
class PromiseLine {
  const PromiseLine({required this.tier, this.label, this.when});

  final String tier;
  final String? label;
  final String? when;

  factory PromiseLine.fromJson(Map<String, dynamic> json) => PromiseLine(
        tier: asString(json['tier'], fallback: 'shipping'),
        label: asStringOrNull(json['label']),
        // The server joins date and relative with an em dash; a group with no
        // dates at all collapses to a bare "—", which is worse than nothing.
        when: _cleanWhen(asStringOrNull(json['when'])),
      );

  static String? _cleanWhen(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.replaceAll(RegExp(r'^[\s—–-]+|[\s—–-]+$'), '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The whole delivery promise for this order.
@immutable
class DeliveryPromise {
  const DeliveryPromise({this.isSplit = false, this.lines = const []});

  final bool isSplit;
  final List<PromiseLine> lines;

  bool get isEmpty => lines.isEmpty;

  factory DeliveryPromise.fromJson(Map<String, dynamic> json) => DeliveryPromise(
        isSplit: asBool(json['is_split']),
        lines: asMapList(json['lines']).map(PromiseLine.fromJson).toList(),
      );
}

/// `GET /checkout` — the review screen's payload. It is the cart DTO plus the
/// three things only checkout needs: who can be delivered to, how it can be
/// paid for, and what we are promising.
@immutable
class CheckoutReview {
  const CheckoutReview({
    this.shipments = const [],
    this.items = const [],
    this.totals = const CartTotals(),
    this.freeShipping = const FreeShipping(),
    this.coupons = const [],
    this.notices = const [],
    this.paymentMethods = const [],
    this.addresses = const [],
    this.promise = const DeliveryPromise(),
  });

  final List<Shipment> shipments;
  final List<CartItem> items;
  final CartTotals totals;
  final FreeShipping freeShipping;
  final List<CartCoupon> coupons;
  final List<CartNotice> notices;
  final List<PaymentMethod> paymentMethods;
  final List<Address> addresses;
  final DeliveryPromise promise;

  int get itemCount => items.fold(0, (sum, item) => sum + item.qty);

  Address? get defaultAddress {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  factory CheckoutReview.fromJson(Map<String, dynamic> json) => CheckoutReview(
        shipments: asMapList(json['shipments']).map(Shipment.fromJson).toList(),
        items: asMapList(json['items']).map(CartItem.fromJson).toList(),
        totals: CartTotals.fromJson(asMap(json['totals'])),
        freeShipping: FreeShipping.fromJson(asMap(json['free_shipping'])),
        coupons: asMapList(json['coupons']).map(CartCoupon.fromJson).toList(),
        notices: asMapList(json['notices']).map(CartNotice.fromJson).toList(),
        paymentMethods:
            asMapList(json['payment_methods']).map(PaymentMethod.fromJson).toList(),
        addresses: asMapList(json['addresses']).map(Address.fromJson).toList(),
        promise: DeliveryPromise.fromJson(asMap(json['promise'])),
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
    this.paymentMethod = 'cod',
    this.paymentRequired = false,
    this.promise = const DeliveryPromise(),
  });

  final int orderId;
  final String orderNumber;
  final String orderKey;
  final String status;
  final double total;
  final String paymentMethod;

  /// False for cash on delivery — the success screen is the end of the flow.
  final bool paymentRequired;

  /// Carried over from the review screen so the success moment can repeat the
  /// dated promise without a second round trip.
  final DeliveryPromise promise;

  PlacedOrder withPromise(DeliveryPromise value) => PlacedOrder(
        orderId: orderId,
        orderNumber: orderNumber,
        orderKey: orderKey,
        status: status,
        total: total,
        paymentMethod: paymentMethod,
        paymentRequired: paymentRequired,
        promise: value,
      );

  factory PlacedOrder.fromJson(Map<String, dynamic> json) => PlacedOrder(
        orderId: asInt(json['order_id']),
        orderNumber: asString(json['order_number']),
        orderKey: asString(json['order_key']),
        status: asString(json['status']),
        total: asDouble(json['total']),
        paymentMethod: asString(json['payment_method'], fallback: 'cod'),
        paymentRequired: asBool(json['payment_required']),
      );
}
