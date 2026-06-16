// Models for the Zooboxi express-order fulfillment feature
// (GET /zooboxi-orders/*).

class ZooboxiOrderLine {
  final int id;
  final String itemCode;
  final String? itemName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  ZooboxiOrderLine({
    required this.id,
    required this.itemCode,
    this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory ZooboxiOrderLine.fromJson(Map<String, dynamic> json) => ZooboxiOrderLine(
        id: json['id'] ?? 0,
        itemCode: json['item_code']?.toString() ?? '',
        itemName: json['item_name']?.toString(),
        quantity: _toDouble(json['quantity']),
        unitPrice: _toDouble(json['unit_price']),
        totalPrice: _toDouble(json['total_price']),
      );

  /// What the manager confirms: the product name (fallback to its code).
  String get displayName => (itemName != null && itemName!.isNotEmpty) ? itemName! : itemCode;
}

class ZooboxiCustomer {
  final String? name;
  final String? phone;
  final String? city;
  final String? address;

  ZooboxiCustomer({this.name, this.phone, this.city, this.address});

  factory ZooboxiCustomer.fromJson(Map<String, dynamic> json) => ZooboxiCustomer(
        name: json['name']?.toString(),
        phone: json['phone']?.toString(),
        city: json['city']?.toString(),
        address: json['address']?.toString(),
      );
}

class ZooboxiOrder {
  final int id;
  final int wooOrderId;
  final String? wooOrderNumber;
  final String warehouseCode;
  final String deliveryType; // express | same_day | shipping | pickup
  final String deliveryTypeLabel;
  final String deliveryStatus; // pending | preparing | ready_for_pickup | ...
  final String deliveryStatusLabel;
  final ZooboxiCustomer customer;
  final double subtotal;
  final double deliveryFee;
  final double taxAmount;
  final double totalAmount;
  final double totalItems;
  final int minutesSinceCreated;
  final String? createdAt;
  final List<ZooboxiOrderLine> lines;

  ZooboxiOrder({
    required this.id,
    required this.wooOrderId,
    this.wooOrderNumber,
    required this.warehouseCode,
    this.deliveryType = 'express',
    this.deliveryTypeLabel = '',
    this.deliveryStatus = 'pending',
    this.deliveryStatusLabel = '',
    required this.customer,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.totalItems = 0,
    this.minutesSinceCreated = 0,
    this.createdAt,
    this.lines = const [],
  });

  factory ZooboxiOrder.fromJson(Map<String, dynamic> json) => ZooboxiOrder(
        id: json['id'] ?? 0,
        wooOrderId: json['woo_order_id'] ?? 0,
        wooOrderNumber: json['woo_order_number']?.toString(),
        warehouseCode: json['warehouse_code']?.toString() ?? '',
        deliveryType: json['delivery_type']?.toString() ?? 'express',
        deliveryTypeLabel: json['delivery_type_label']?.toString() ?? '',
        deliveryStatus: json['delivery_status']?.toString() ?? 'pending',
        deliveryStatusLabel: json['delivery_status_label']?.toString() ?? '',
        customer: ZooboxiCustomer.fromJson(
            Map<String, dynamic>.from((json['customer'] as Map?) ?? {})),
        subtotal: _toDouble((json['totals'] as Map?)?['subtotal']),
        deliveryFee: _toDouble((json['totals'] as Map?)?['delivery_fee']),
        taxAmount: _toDouble((json['totals'] as Map?)?['tax_amount']),
        totalAmount: _toDouble((json['totals'] as Map?)?['total_amount']),
        totalItems: _toDouble(json['total_items']),
        minutesSinceCreated: (json['minutes_since_created'] is num)
            ? (json['minutes_since_created'] as num).round()
            : int.tryParse('${json['minutes_since_created']}') ?? 0,
        createdAt: json['created_at']?.toString(),
        lines: ((json['lines'] as List?) ?? [])
            .map((e) => ZooboxiOrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  bool get isPending => deliveryStatus == 'pending';
  bool get isPreparing => deliveryStatus == 'preparing';

  /// Still waiting on the branch (shown in the "تنتظر" tab).
  bool get isWaiting => isPending || isPreparing;

  /// Prepared / handed off (shown in the "تمت" tab).
  bool get isDone =>
      deliveryStatus == 'ready_for_pickup' ||
      deliveryStatus == 'out_for_delivery' ||
      deliveryStatus == 'delivered';

  /// A short order reference for headers/cards.
  String get reference => (wooOrderNumber != null && wooOrderNumber!.isNotEmpty)
      ? wooOrderNumber!
      : '#$wooOrderId';
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
