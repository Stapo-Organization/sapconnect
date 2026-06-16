// Models for product search & detail — mirror the
// GET /products/search and GET /products/{itemCode}/detail payloads.

double _d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
double? _dn(dynamic v) => (v is num) ? v.toDouble() : null;
int _i(dynamic v) => (v is num) ? v.toInt() : 0;
String? _s(dynamic v) => (v == null) ? null : v.toString();

/// A single hit in the search results list.
class ProductHit {
  final String itemCode;
  final String name;
  final String? nameEn;
  final String? barcode;
  final String imageUrl;
  final double totalStock; // network-wide

  ProductHit({
    required this.itemCode,
    required this.name,
    required this.nameEn,
    required this.barcode,
    required this.imageUrl,
    required this.totalStock,
  });

  factory ProductHit.fromJson(Map<String, dynamic> j) => ProductHit(
        itemCode: (j['item_code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        nameEn: _s(j['name_en']),
        barcode: _s(j['barcode']),
        imageUrl: (j['image_url'] ?? '').toString(),
        totalStock: _d(j['total_stock']),
      );
}

/// One warehouse's stock line on the detail page.
class WarehouseStock {
  final String warehouseCode;
  final String warehouseName;
  final double inStock;
  final double committed; // reserved by sales orders
  final double ordered;   // inbound on purchase orders

  WarehouseStock({
    required this.warehouseCode,
    required this.warehouseName,
    required this.inStock,
    required this.committed,
    required this.ordered,
  });

  /// Sellable now (SAP's "Available"): in stock − committed + on order.
  double get available => inStock - committed + ordered;

  factory WarehouseStock.fromJson(Map<String, dynamic> j) => WarehouseStock(
        warehouseCode: (j['warehouse_code'] ?? '').toString(),
        warehouseName: (j['warehouse_name'] ?? '').toString(),
        inStock: _d(j['in_stock']),
        committed: _d(j['committed']),
        ordered: _d(j['ordered']),
      );
}

/// Full product detail: identity + stock across every warehouse & showroom.
class ProductDetail {
  final String itemCode;
  final String name;
  final String? nameEn;
  final String? barcode;
  final String imageUrl;
  final String? uom;
  final String? brand;
  final double? retailPrice;
  final double totalStock;
  final double totalCommitted;
  final double totalOrdered;
  final int warehouseCount; // warehouses with in_stock > 0
  final List<WarehouseStock> warehouses;

  ProductDetail({
    required this.itemCode,
    required this.name,
    required this.nameEn,
    required this.barcode,
    required this.imageUrl,
    required this.uom,
    required this.brand,
    required this.retailPrice,
    required this.totalStock,
    required this.totalCommitted,
    required this.totalOrdered,
    required this.warehouseCount,
    required this.warehouses,
  });

  /// Network-wide sellable: total in stock − committed + on order.
  double get totalAvailable => totalStock - totalCommitted + totalOrdered;

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        itemCode: (j['item_code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        nameEn: _s(j['name_en']),
        barcode: _s(j['barcode']),
        imageUrl: (j['image_url'] ?? '').toString(),
        uom: _s(j['uom']),
        brand: _s(j['brand']),
        retailPrice: _dn(j['retail_price']),
        totalStock: _d(j['total_stock']),
        totalCommitted: _d(j['total_committed']),
        totalOrdered: _d(j['total_ordered']),
        warehouseCount: _i(j['warehouse_count']),
        warehouses: ((j['warehouses'] as List?) ?? [])
            .map((e) => WarehouseStock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
