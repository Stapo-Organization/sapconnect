import 'package:flutter/foundation.dart';

import '../../../core/network/envelope.dart';
import '../../account/data/account_models.dart';
import '../../cart/data/cart_models.dart';

/// A thumbnail row in the orders list — enough to recognise an order without
/// opening it.
@immutable
class OrderItemPreview {
  const OrderItemPreview({required this.name, this.image, this.qty = 1});

  final String name;
  final String? image;
  final int qty;

  factory OrderItemPreview.fromJson(Map<String, dynamic> json) => OrderItemPreview(
        name: asString(json['name']),
        image: asStringOrNull(json['image']),
        qty: asInt(json['qty'], fallback: 1),
      );
}

@immutable
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.number,
    required this.status,
    this.orderKey = '',
    this.date,
    this.statusLabel,
    this.total = 0,
    this.isPaid = false,
    this.paymentMethod,
    this.deliveryType,
    this.itemsPreview = const [],
    this.itemsCount = 0,
    this.canReorder = false,
  });

  final int id;
  final String number;

  /// Gates the public pay/status routes — the only way back to an unpaid
  /// order without a bearer token.
  final String orderKey;
  final DateTime? date;

  /// Machine status (`processing`, `zb-ready`, `completed`, …).
  final String status;

  /// Already localized by the server.
  final String? statusLabel;
  final double total;
  final bool isPaid;
  final String? paymentMethod;
  final String? deliveryType;
  final List<OrderItemPreview> itemsPreview;
  final int itemsCount;
  final bool canReorder;

  /// An order the customer can still pay for: an online gateway was chosen,
  /// the money never landed, and the order has not been called off.
  bool get awaitsPayment =>
      !isPaid &&
      orderKey.isNotEmpty &&
      paymentMethod != 'cod' &&
      const {'pending', 'failed', 'on-hold'}.contains(status);

  bool get isCancelled => status == 'cancelled' || status == 'refunded';

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: asInt(json['id']),
        number: asString(json['number']),
        orderKey: asString(json['order_key']),
        date: asDate(json['date']),
        status: asString(json['status']),
        statusLabel: asStringOrNull(json['status_label']),
        total: asDouble(json['total']),
        isPaid: asBool(json['is_paid']),
        paymentMethod: asStringOrNull(json['payment_method']),
        deliveryType: asStringOrNull(json['delivery_type']),
        itemsPreview:
            asMapList(json['items_preview']).map(OrderItemPreview.fromJson).toList(),
        itemsCount: asInt(json['items_count']),
        canReorder: asBool(json['can_reorder']),
      );
}

/// One step of the order's progress. [done] is the server's call — the app
/// never infers progress from the status string.
@immutable
class OrderTimelineStep {
  const OrderTimelineStep({required this.key, required this.label, this.at, this.done = false});

  final String key;
  final String label;
  final DateTime? at;
  final bool done;

  factory OrderTimelineStep.fromJson(Map<String, dynamic> json) => OrderTimelineStep(
        key: asString(json['key']),
        label: asString(json['label']),
        at: asDate(json['at']),
        done: asBool(json['done']),
      );
}

@immutable
class OrderTracking {
  const OrderTracking({this.number, this.carrier, this.url, this.status});

  final String? number;
  final String? carrier;
  final String? url;

  /// The carrier's own wording, e.g. `dispatched`. Shown verbatim when set.
  final String? status;

  static OrderTracking? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final tracking = OrderTracking(
      number: asStringOrNull(map['number']),
      carrier: asStringOrNull(map['carrier']),
      url: asStringOrNull(map['url']),
      status: asStringOrNull(map['status']),
    );
    return tracking.number == null && tracking.url == null ? null : tracking;
  }
}

@immutable
class OrderLine {
  const OrderLine({
    required this.name,
    this.productId = 0,
    this.variationId,
    this.image,
    this.qty = 1,
    this.total = 0,
  });

  final String name;
  final int productId;
  final int? variationId;
  final String? image;
  final int qty;
  final double total;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        name: asString(json['name']),
        productId: asInt(json['product_id']),
        variationId: asIntOrNull(json['variation_id']),
        image: asStringOrNull(json['image']),
        qty: asInt(json['qty'], fallback: 1),
        total: asDouble(json['line_total'] ?? json['total']),
      );
}

@immutable
class OrderDetail {
  const OrderDetail({
    required this.summary,
    this.items = const [],
    this.address,
    this.totals = const CartTotals(),
    this.timeline = const [],
    this.tracking,
    this.notes,
  });

  final OrderSummary summary;
  final List<OrderLine> items;
  final Address? address;
  final CartTotals totals;
  final List<OrderTimelineStep> timeline;
  final OrderTracking? tracking;

  /// The customer's own note at checkout ("اتصل قبل الوصول").
  final String? notes;

  bool get canReorder => summary.canReorder;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final addressJson = asMap(json['address']);
    return OrderDetail(
      summary: OrderSummary.fromJson(json),
      items: asMapList(json['items']).map(OrderLine.fromJson).toList(),
      address: addressJson.isEmpty ? null : Address.fromJson(addressJson),
      totals: CartTotals.fromJson(asMap(json['totals'])),
      timeline: asMapList(json['timeline']).map(OrderTimelineStep.fromJson).toList(),
      tracking: OrderTracking.maybe(json['tracking']),
      notes: asStringOrNull(json['notes']),
    );
  }
}

/// `POST /orders/{id}/reorder` — the refilled cart, plus what could not come
/// back. The missing names are the whole point: "3 added, 1 unavailable" is
/// the honest answer, and the customer decides what to do about it.
@immutable
class ReorderResult {
  const ReorderResult({required this.cart, this.added = 0, this.missing = const []});

  final CartData cart;
  final int added;
  final List<String> missing;

  factory ReorderResult.fromJson(Map<String, dynamic> json) => ReorderResult(
        cart: CartData.fromJson(json),
        added: asInt(json['added']),
        missing: asStringList(json['missing']),
      );
}

/// One page of `GET /orders`.
@immutable
class OrdersPage {
  const OrdersPage({this.orders = const [], this.total = 0, this.page = 1, this.pages = 1});

  final List<OrderSummary> orders;
  final int total;
  final int page;
  final int pages;

  bool get hasMore => page < pages;

  factory OrdersPage.fromJson(Map<String, dynamic> json) => OrdersPage(
        orders: asMapList(json['orders']).map(OrderSummary.fromJson).toList(),
        total: asInt(json['total']),
        page: asInt(json['page'], fallback: 1),
        pages: asInt(json['pages'], fallback: 1),
      );
}
