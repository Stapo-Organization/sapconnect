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
    this.date,
    this.statusLabel,
    this.total = 0,
    this.isPaid = false,
    this.deliveryType,
    this.itemsPreview = const [],
  });

  final int id;
  final String number;
  final DateTime? date;

  /// Machine status (`processing`, `wc-zb-ready`, `completed`, …).
  final String status;

  /// Already localized by the server.
  final String? statusLabel;
  final double total;
  final bool isPaid;
  final String? deliveryType;
  final List<OrderItemPreview> itemsPreview;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: asInt(json['id']),
        number: asString(json['number']),
        date: asDate(json['date']),
        status: asString(json['status']),
        statusLabel: asStringOrNull(json['status_label']),
        total: asDouble(json['total']),
        isPaid: asBool(json['is_paid']),
        deliveryType: asStringOrNull(json['delivery_type']),
        itemsPreview: asMapList(json['items_preview']).map(OrderItemPreview.fromJson).toList(),
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
  const OrderTracking({this.number, this.url});

  final String? number;
  final String? url;

  static OrderTracking? maybe(dynamic value) {
    final map = asMap(value);
    if (map.isEmpty) return null;
    final tracking = OrderTracking(
      number: asStringOrNull(map['number']),
      url: asStringOrNull(map['url']),
    );
    return tracking.number == null && tracking.url == null ? null : tracking;
  }
}

@immutable
class OrderLine {
  const OrderLine({required this.name, this.image, this.qty = 1, this.total = 0});

  final String name;
  final String? image;
  final int qty;
  final double total;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        name: asString(json['name']),
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
    this.canReorder = false,
  });

  final OrderSummary summary;
  final List<OrderLine> items;
  final Address? address;
  final CartTotals totals;
  final List<OrderTimelineStep> timeline;
  final OrderTracking? tracking;
  final bool canReorder;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final addressJson = asMap(json['address']);
    return OrderDetail(
      summary: OrderSummary.fromJson(json),
      items: asMapList(json['items']).map(OrderLine.fromJson).toList(),
      address: addressJson.isEmpty ? null : Address.fromJson(addressJson),
      totals: CartTotals.fromJson(asMap(json['totals'])),
      timeline: asMapList(json['timeline']).map(OrderTimelineStep.fromJson).toList(),
      tracking: OrderTracking.maybe(json['tracking']),
      canReorder: asBool(json['can_reorder']),
    );
  }
}

/// One page of `GET /orders`.
@immutable
class OrdersPage {
  const OrdersPage({this.orders = const [], this.total = 0, this.pages = 1});

  final List<OrderSummary> orders;
  final int total;
  final int pages;

  factory OrdersPage.fromJson(Map<String, dynamic> json) => OrdersPage(
        orders: asMapList(json['orders']).map(OrderSummary.fromJson).toList(),
        total: asInt(json['total']),
        pages: asInt(json['pages'], fallback: 1),
      );
}
