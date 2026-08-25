import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';

/// Per-line fulfilment: which tier serves this line, and whether the quantity
/// had to be split because the fast source doesn't hold enough.
@immutable
class LineFulfillment {
  const LineFulfillment({this.headline, this.tier, this.isSplit = false, this.shortfall = 0});

  final String? headline;
  final String? tier;

  /// True when part of this line ships from a slower source.
  final bool isSplit;

  /// How many units fall back to the slower tier.
  final int shortfall;

  factory LineFulfillment.fromJson(Map<String, dynamic> json) => LineFulfillment(
        headline: asStringOrNull(json['headline']),
        tier: asStringOrNull(json['tier']),
        isSplit: asBool(json['is_split']),
        shortfall: asInt(json['shortfall']),
      );
}

@immutable
class CartItem {
  const CartItem({
    required this.key,
    required this.productId,
    required this.name,
    this.variationId,
    this.image,
    this.attributesLabel,
    this.qty = 1,
    this.maxReachable,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.fulfillment,
  });

  /// WooCommerce's cart line key — the id for PATCH/DELETE, not the product id
  /// (the same product can appear twice with different variations).
  final String key;
  final int productId;
  final int? variationId;
  final String name;
  final String? image;

  /// Pre-joined variant summary, e.g. "دجاج · 400 جم".
  final String? attributesLabel;
  final int qty;

  /// The real cap for this customer's location — the stepper never exceeds it.
  final int? maxReachable;
  final double unitPrice;
  final double lineTotal;
  final LineFulfillment? fulfillment;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        key: asString(json['key']),
        productId: asInt(json['product_id']),
        variationId: asIntOrNull(json['variation_id']),
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        attributesLabel: asStringOrNull(json['attributes_label']),
        qty: asInt(json['qty'], fallback: 1),
        maxReachable: asIntOrNull(json['max_reachable']),
        unitPrice: asDouble(json['unit_price']),
        lineTotal: asDouble(json['line_total']),
        fulfillment: asMap(json['fulfillment']).isEmpty
            ? null
            : LineFulfillment.fromJson(asMap(json['fulfillment'])),
      );

  /// Used for the optimistic update: the line total is recomputed locally so
  /// the number moves the instant the customer taps, then the server's
  /// authoritative figure replaces it.
  CartItem withQty(int newQty) => CartItem(
        key: key,
        productId: productId,
        variationId: variationId,
        name: name,
        image: image,
        attributesLabel: attributesLabel,
        qty: newQty,
        maxReachable: maxReachable,
        unitPrice: unitPrice,
        lineTotal: unitPrice * newQty,
        fulfillment: fulfillment,
      );
}

/// One shipment group — the app always renders these, because a split basket
/// is the truth of a multi-warehouse store and hiding it makes the promise a
/// lie for the slower half.
@immutable
class Shipment {
  const Shipment({
    required this.tier,
    this.name,
    this.icon,
    this.color,
    this.dateLabel,
    this.relativeLabel,
    this.fee = 0,
    this.free = false,
    this.lines = const [],
  });

  final String tier;
  final String? name;
  final String? icon;
  final String? color;
  final String? dateLabel;
  final String? relativeLabel;
  final double fee;
  final bool free;
  final List<ShipmentLine> lines;

  // The server calls the human title `label` (`tier_presentation()['name']`
  // serialized as `label`); `name` is accepted as a fallback so an older
  // build of the plugin still renders a title rather than the raw tier key.
  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        tier: asString(json['tier'], fallback: 'shipping'),
        name: asStringOrNull(json['label']) ?? asStringOrNull(json['name']),
        icon: asStringOrNull(json['icon']),
        color: asStringOrNull(json['color']),
        dateLabel: asStringOrNull(json['date_label']),
        relativeLabel: asStringOrNull(json['relative_label']),
        fee: asDouble(json['fee']),
        free: asBool(json['free']),
        lines: asMapList(json['lines']).map(ShipmentLine.fromJson).toList(),
      );
}

@immutable
class ShipmentLine {
  const ShipmentLine({required this.name, this.qty = 1});

  final String name;
  final int qty;

  factory ShipmentLine.fromJson(Map<String, dynamic> json) =>
      ShipmentLine(name: asString(json['name']), qty: asInt(json['qty'], fallback: 1));
}

@immutable
class CartTotals {
  const CartTotals({
    this.subtotal = 0,
    this.discount = 0,
    this.shipping = 0,
    this.tax = 0,
    this.total = 0,
  });

  final double subtotal;
  final double discount;
  final double shipping;
  final double tax;
  final double total;

  factory CartTotals.fromJson(Map<String, dynamic> json) => CartTotals(
        subtotal: asDouble(json['subtotal']),
        discount: asDouble(json['discount']),
        shipping: asDouble(json['shipping']),
        tax: asDouble(json['tax']),
        total: asDouble(json['total']),
      );
}

/// Free-shipping progress. The threshold comes from the server so the app and
/// the website can never disagree about it.
@immutable
class FreeShipping {
  const FreeShipping({this.min = 0, this.remaining = 0, this.qualified = false});

  final double min;
  final double remaining;
  final bool qualified;

  bool get isActive => min > 0;

  /// 0..1 for the progress bar.
  double get progress {
    if (!isActive) return 0;
    if (qualified) return 1;
    return ((min - remaining) / min).clamp(0.0, 1.0);
  }

  factory FreeShipping.fromJson(Map<String, dynamic> json) => FreeShipping(
        min: asDouble(json['min']),
        remaining: asDouble(json['remaining']),
        qualified: asBool(json['qualified']),
      );
}

@immutable
class CartCoupon {
  const CartCoupon({required this.code, this.amount = 0});

  final String code;
  final double amount;

  factory CartCoupon.fromJson(Map<String, dynamic> json) =>
      CartCoupon(code: asString(json['code']), amount: asDouble(json['amount']));
}

/// A message drained from WooCommerce's notice stack — this is how the
/// server tells us it capped a quantity or dropped an unreachable line.
@immutable
class CartNotice {
  const CartNotice({required this.type, required this.text});

  final String type;
  final String text;

  bool get isError => type == 'error';

  factory CartNotice.fromJson(Map<String, dynamic> json) =>
      CartNotice(type: asString(json['type'], fallback: 'notice'), text: asString(json['text']));
}

/// The whole cart, server-authoritative. Every mutation returns a fresh copy
/// of this — the app never computes totals, shipping or caps itself.
@immutable
class CartData {
  const CartData({
    this.items = const [],
    this.shipments = const [],
    this.totals = const CartTotals(),
    this.freeShipping = const FreeShipping(),
    this.coupons = const [],
    this.notices = const [],
    this.count = 0,
  });

  final List<CartItem> items;
  final List<Shipment> shipments;
  final CartTotals totals;
  final FreeShipping freeShipping;
  final List<CartCoupon> coupons;
  final List<CartNotice> notices;

  /// Total units — what the tab badge shows.
  final int count;

  bool get isEmpty => items.isEmpty;

  static const CartData empty = CartData();

  factory CartData.fromJson(Map<String, dynamic> json) => CartData(
        items: asMapList(json['items']).map(CartItem.fromJson).toList(),
        shipments: asMapList(json['shipments']).map(Shipment.fromJson).toList(),
        totals: CartTotals.fromJson(asMap(json['totals'])),
        freeShipping: FreeShipping.fromJson(asMap(json['free_shipping'])),
        coupons: asMapList(json['coupons']).map(CartCoupon.fromJson).toList(),
        notices: asMapList(json['notices']).map(CartNotice.fromJson).toList(),
        count: asInt(json['count']),
      );

  /// Local echo of a quantity change, used between the tap and the server's
  /// answer. Totals shift by the line delta only — shipping and tax are the
  /// server's to decide, so they are left alone rather than guessed.
  CartData withItemQty(String key, int qty) {
    final index = items.indexWhere((e) => e.key == key);
    if (index < 0) return this;
    final old = items[index];
    final updated = old.withQty(qty);
    final delta = updated.lineTotal - old.lineTotal;
    final nextItems = [...items]..[index] = updated;

    return CartData(
      items: nextItems,
      shipments: shipments,
      totals: CartTotals(
        subtotal: totals.subtotal + delta,
        discount: totals.discount,
        shipping: totals.shipping,
        tax: totals.tax,
        total: totals.total + delta,
      ),
      freeShipping: freeShipping,
      coupons: coupons,
      notices: const [],
      count: count + (qty - old.qty),
    );
  }

  CartData withoutItem(String key) {
    final index = items.indexWhere((e) => e.key == key);
    if (index < 0) return this;
    final removed = items[index];
    final nextItems = [...items]..removeAt(index);
    return CartData(
      items: nextItems,
      shipments: shipments,
      totals: CartTotals(
        subtotal: totals.subtotal - removed.lineTotal,
        discount: totals.discount,
        shipping: totals.shipping,
        tax: totals.tax,
        total: totals.total - removed.lineTotal,
      ),
      freeShipping: freeShipping,
      coupons: coupons,
      notices: const [],
      count: (count - removed.qty).clamp(0, 1 << 30),
    );
  }
}
