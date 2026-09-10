import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import '../../loyalty/data/loyalty_models.dart';

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
    this.isGift = false,
    this.grantId,
    this.lockedQty = false,
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

  /// A claimed reward riding in the basket at a price of zero. It is a real
  /// line — it picks, it ships, it leaves the warehouse — so it is a cart item
  /// like any other, just one the customer cannot re-price or re-count.
  final bool isGift;

  /// The grant this line came from; removing the line releases that claim.
  final int? grantId;

  /// The quantity is the server's, not the customer's: one gift is one gift.
  final bool lockedQty;

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
        isGift: asBool(json['is_gift']),
        grantId: asIntOrNull(json['grant_id']),
        lockedQty: asBool(json['locked_qty']),
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
        isGift: isGift,
        grantId: grantId,
        lockedQty: lockedQty,
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
  const FreeShipping({this.min = 0, this.remaining = 0, this.qualified = false, this.express});

  final double min;
  final double remaining;
  final bool qualified;

  /// The express basket's own, lower line. Null from a store that predates
  /// it; the bar then falls back to the national threshold as before.
  final FreeShipping? express;

  /// The line this basket should measure itself against.
  FreeShipping forShelf(String shelf) =>
      shelf == 'express' && express != null && express!.isActive ? express! : this;

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
        express: json['express'] is Map ? FreeShipping.fromJson(asMap(json['express'])) : null,
      );

  // Value equality, because Home listens for this and nothing else about the
  // cart. Every basket answer decodes a fresh instance, so without this the
  // whole storefront rebuilt on a quantity tap that never moved the bar.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreeShipping &&
          other.min == min &&
          other.remaining == remaining &&
          other.express == express &&
          other.qualified == qualified;

  @override
  int get hashCode => Object.hash(min, remaining, qualified);
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

/// What moving between the two storefronts' baskets actually did.
///
/// The store sends this beside every basket response. It matters most for the
/// move nobody pressed a button for — the basket following the tab — where a
/// badge that drops from twelve to zero has to be explained in the same
/// breath, or it reads as loss.
@immutable
class BasketMove {
  const BasketMove({
    this.to = '',
    this.from = '',
    this.auto = false,
    this.restored = 0,
    this.stashed = 0,
    this.lost = 0,
    this.notices = const [],
  });

  /// The storefront now holding the live basket.
  final String to;

  /// The storefront whose basket was put away, empty when there was none.
  final String from;

  /// Whether the basket moved by itself, following the shelf being browsed.
  final bool auto;

  final int restored;
  final int stashed;

  /// Lines that could not come back because the store no longer has them.
  final int lost;

  /// The store's own sentences about it, already in the customer's language.
  final List<CartNotice> notices;

  /// Nothing was carried either way — the alignment was a formality and must
  /// not interrupt anyone.
  bool get isQuiet => restored == 0 && stashed == 0 && lost == 0;

  factory BasketMove.fromJson(
    Map<String, dynamic> json, {
    List<CartNotice> notices = const [],
  }) =>
      BasketMove(
        to: asString(json['to']),
        from: asString(json['from']),
        auto: asBool(json['auto']),
        restored: asInt(json['restored']),
        stashed: asInt(json['stashed']),
        lost: asInt(json['lost']),
        notices: notices,
      );

  /// Null when the store said nothing moved, or is too old to say.
  static BasketMove? maybe(dynamic value, {List<CartNotice> notices = const []}) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    // `moved: false` is the store telling us the basket was already right.
    if (map.containsKey('moved') && !asBool(map['moved'])) return null;
    return BasketMove.fromJson(map, notices: notices);
  }
}

/// The whole cart, server-authoritative. Every mutation returns a fresh copy
/// of this — the app never computes totals, shipping or caps itself.
@immutable
/// Which storefront this basket belongs to, and what is waiting in the other.
///
/// إكسبريس and زوبكسي are two shops: an order is one or the other, never a
/// mixture. The basket the customer is not using is not thrown away — it waits
/// on the server and comes back whole when they switch to it.
@immutable
class CartBasket {
  const CartBasket({
    this.shelf = '',
    this.otherShelf = '',
    this.otherCount = 0,
    this.otherUnits,
    this.started = true,
    this.effectiveShelf = '',
    this.requestedShelf = '',
    this.otherServes = true,
    this.otherSince,
  });

  /// `express` | `all`, or empty while the basket is empty and belongs to
  /// neither.
  final String shelf;
  final String otherShelf;

  /// Lines waiting in the other storefront's basket.
  final int otherCount;

  /// Pieces waiting there — [otherCount] counts products, this counts what
  /// the cart counts. Null from a store too old to say, where the line count
  /// is the closest true answer.
  final int? otherUnits;

  /// The number to WEAR: the waiting basket measured the same way the live
  /// one is, so the two shop signs can never disagree about the same basket.
  int get otherPieces => otherUnits ?? otherCount;

  /// False when there is no basket yet and the product being added simply
  /// belongs to the other storefront — a different sentence from "your basket
  /// is from the other store".
  final bool started;

  /// The storefront the server actually SERVED this request as. Empty when
  /// the caller named no tab (the website) — nothing to disagree with.
  final String effectiveShelf;

  /// The tab the app asked for. Kept for the rare case where the two differ
  /// and the difference itself is the thing worth saying.
  final String requestedShelf;

  /// Whether the waiting basket could actually be delivered right now. False
  /// while its branch is shut, when the honest answer is «تفتح ٩ ص» rather
  /// than a button that quietly fails.
  final bool otherServes;

  /// When the waiting basket was put down, if the store knows.
  final DateTime? otherSince;

  bool get isSet => shelf.isNotEmpty;
  bool get otherHasItems => otherShelf.isNotEmpty && otherCount > 0;

  /// The basket belongs to one storefront while the shop being served is the
  /// other one.
  ///
  /// This is the state the customer used to be left to discover for
  /// themselves: browsing what looked like إكسبريس, adding a line, and finding
  /// a cart full of زوبكسي products. Both halves come from the SAME response,
  /// so it can never be an artifact of one of them being stale.
  bool get mismatched =>
      shelf.isNotEmpty && effectiveShelf.isNotEmpty && shelf != effectiveShelf;

  static const CartBasket none = CartBasket();

  factory CartBasket.fromJson(Map<String, dynamic> json) => CartBasket(
        shelf: asString(json['shelf']),
        otherShelf: asString(json['other_shelf']),
        otherCount: asInt(json['other_count']),
        otherUnits:
            json.containsKey('other_units') ? asInt(json['other_units']) : null,
        started: json.containsKey('started') ? asBool(json['started']) : true,
        effectiveShelf: asString(json['effective_shelf']),
        requestedShelf: asString(json['requested_shelf']),
        // Absent on a store that predates the field: assume it can be served,
        // which is what every build before this one already assumed.
        otherServes:
            json.containsKey('other_serves') ? asBool(json['other_serves']) : true,
        otherSince: _sinceOf(json['other_since']),
      );

  /// A unix stamp from the store, or null when it never knew.
  static DateTime? _sinceOf(dynamic value) {
    final seconds = asIntOrNull(value);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

class CartData {
  const CartData({
    this.items = const [],
    this.shipments = const [],
    this.totals = const CartTotals(),
    this.freeShipping = const FreeShipping(),
    this.coupons = const [],
    this.notices = const [],
    this.count = 0,
    this.loyalty = CartLoyalty.none,
    this.basket = CartBasket.none,
  });

  final List<CartItem> items;
  final List<Shipment> shipments;
  final CartTotals totals;
  final FreeShipping freeShipping;
  final List<CartCoupon> coupons;
  final List<CartNotice> notices;

  /// Total units — what the tab badge shows.
  final int count;

  /// The storefront this basket belongs to, and the one waiting beside it.
  final CartBasket basket;

  /// What this basket earns, what it already carries, and why delivery costs
  /// what it costs. Absent for a store that has the program switched off, in
  /// which case every loyalty affordance in the cart simply never draws.
  final CartLoyalty loyalty;

  bool get isEmpty => items.isEmpty;

  /// The gift lines, which the cart screen renders differently from the rest.
  List<CartItem> get giftItems =>
      items.where((item) => item.isGift).toList(growable: false);

  static const CartData empty = CartData();

  factory CartData.fromJson(Map<String, dynamic> json) => CartData(
        items: asMapList(json['items']).map(CartItem.fromJson).toList(),
        shipments: asMapList(json['shipments']).map(Shipment.fromJson).toList(),
        totals: CartTotals.fromJson(asMap(json['totals'])),
        freeShipping: FreeShipping.fromJson(asMap(json['free_shipping'])),
        coupons: asMapList(json['coupons']).map(CartCoupon.fromJson).toList(),
        notices: asMapList(json['notices']).map(CartNotice.fromJson).toList(),
        count: asInt(json['count']),
        loyalty: CartLoyalty.fromJson(asMap(json['loyalty'])),
        basket: CartBasket.fromJson(asMap(json['basket'])),
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
      loyalty: loyalty,
      basket: basket,
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
      loyalty: loyalty,
      basket: basket,
    );
  }
}
