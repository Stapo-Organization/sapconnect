// Models for «حزم زوبوكسي» (owner only) — backed by GET /bundles/*.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// One component inside a bundle (anchor, member or gift).
class BundleItem {
  final String itemCode;
  final String name;
  final int qty;
  final String role; // anchor | member | gift
  final double unitRetail;
  final String imageUrl;

  BundleItem({
    required this.itemCode,
    required this.name,
    required this.qty,
    required this.role,
    required this.unitRetail,
    required this.imageUrl,
  });

  factory BundleItem.fromJson(Map<String, dynamic> json) => BundleItem(
        itemCode: json['item_code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        role: json['role']?.toString() ?? 'member',
        unitRetail: _toDouble(json['unit_retail']),
        imageUrl: json['image_url']?.toString() ?? '',
      );

  bool get isGift => role == 'gift';
}

/// An auto-suggested sellable bundle awaiting the owner's decision.
class Bundle {
  final int id;
  final String template; // stacking | variety | companion | smart_gift | seasonal
  final String status; // suggested | approved | live | retired | rejected
  final String nameAr;
  final String? subtitleAr;
  final String? freeLabel;
  final String species; // cat | dog | bird | small_pet | mixed
  final double sumRetail;
  final double bundlePrice;
  final double floorPrice;
  final double savingsPct;
  final String stockClass; // express | central
  final List<String> warehouseScope;
  final double score;
  final Map<String, dynamic> rationale;
  final int? wcProductId;
  final String? rejectedReason;
  final List<BundleItem> items;

  Bundle({
    required this.id,
    required this.template,
    required this.status,
    required this.nameAr,
    this.subtitleAr,
    this.freeLabel,
    required this.species,
    required this.sumRetail,
    required this.bundlePrice,
    required this.floorPrice,
    required this.savingsPct,
    required this.stockClass,
    required this.warehouseScope,
    required this.score,
    required this.rationale,
    this.wcProductId,
    this.rejectedReason,
    required this.items,
  });

  factory Bundle.fromJson(Map<String, dynamic> json) => Bundle(
        id: (json['id'] as num?)?.toInt() ?? 0,
        template: json['template']?.toString() ?? 'stacking',
        status: json['status']?.toString() ?? 'suggested',
        nameAr: json['name_ar']?.toString() ?? '',
        subtitleAr: json['subtitle_ar']?.toString(),
        freeLabel: json['free_label']?.toString(),
        species: json['species']?.toString() ?? 'mixed',
        sumRetail: _toDouble(json['sum_retail']),
        bundlePrice: _toDouble(json['bundle_price']),
        floorPrice: _toDouble(json['floor_price']),
        savingsPct: _toDouble(json['savings_pct']),
        stockClass: json['stock_class']?.toString() ?? 'central',
        warehouseScope: ((json['warehouse_scope'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        score: _toDouble(json['score']),
        rationale: Map<String, dynamic>.from((json['rationale'] as Map?) ?? const {}),
        wcProductId: (json['wc_product_id'] as num?)?.toInt(),
        rejectedReason: json['rejected_reason']?.toString(),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => BundleItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  double get savingsValue => sumRetail - bundlePrice;
  BundleItem? get gift {
    for (final it in items) {
      if (it.isGift) return it;
    }
    return null;
  }
}
