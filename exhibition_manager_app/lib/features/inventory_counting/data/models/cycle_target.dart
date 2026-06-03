// Models for the guided cycle-count experience (GET /inventory-countings/{id}/targets).

class CycleTargetItem {
  final String itemCode;
  final String? abcClass;
  final String? itemName;
  final String? itemNameAr;
  final String? itemNameEn;
  final String? pieceBarcode;
  final String? imageUrl;
  final bool counted;
  final double countedQuantity;
  final int scanCount;

  CycleTargetItem({
    required this.itemCode,
    this.abcClass,
    this.itemName,
    this.itemNameAr,
    this.itemNameEn,
    this.pieceBarcode,
    this.imageUrl,
    this.counted = false,
    this.countedQuantity = 0,
    this.scanCount = 0,
  });

  factory CycleTargetItem.fromJson(Map<String, dynamic> json) {
    return CycleTargetItem(
      itemCode: json['item_code'] ?? '',
      abcClass: json['abc_class'],
      itemName: json['item_name'],
      itemNameAr: json['item_name_ar'],
      itemNameEn: json['item_name_en'],
      pieceBarcode: json['piece_barcode'],
      imageUrl: json['image_url'],
      counted: json['counted'] == true,
      countedQuantity: (json['counted_quantity'] ?? 0).toDouble(),
      scanCount: json['scan_count'] ?? 0,
    );
  }

  String localizedName(bool isArabic) {
    if (isArabic) return itemNameAr ?? itemName ?? itemCode;
    return itemNameEn ?? itemName ?? itemCode;
  }
}

class ClassProgress {
  final int total;
  final int counted;
  const ClassProgress({this.total = 0, this.counted = 0});

  factory ClassProgress.fromJson(Map<String, dynamic> json) =>
      ClassProgress(total: json['total'] ?? 0, counted: json['counted'] ?? 0);

  double get percent => total > 0 ? counted / total * 100 : 0;
}

class CycleProgress {
  final int totalTargets;
  final int countedTargets;
  final double percent;
  final Map<String, ClassProgress> byClass;
  final int offListScans;

  CycleProgress({
    this.totalTargets = 0,
    this.countedTargets = 0,
    this.percent = 0,
    this.byClass = const {},
    this.offListScans = 0,
  });

  factory CycleProgress.fromJson(Map<String, dynamic> json) {
    final raw = (json['by_class'] as Map?) ?? {};
    final byClass = <String, ClassProgress>{};
    raw.forEach((k, v) {
      byClass[k.toString()] = ClassProgress.fromJson(Map<String, dynamic>.from(v as Map));
    });
    return CycleProgress(
      totalTargets: json['total_targets'] ?? 0,
      countedTargets: json['counted_targets'] ?? 0,
      percent: (json['percent'] ?? 0).toDouble(),
      byClass: byClass,
      offListScans: json['off_list_scans'] ?? 0,
    );
  }

  int get remaining => (totalTargets - countedTargets).clamp(0, totalTargets);
}

class CycleTargetsResponse {
  final int sessionId;
  final String warehouseCode;
  final String? warehouseName;
  final String countingType;
  final String status;
  final String? scheduledDate;
  final String priority;
  final String? planName;
  final CycleProgress progress;
  final List<CycleTargetItem> items;

  CycleTargetsResponse({
    required this.sessionId,
    required this.warehouseCode,
    this.warehouseName,
    this.countingType = 'cycle',
    this.status = 'in_progress',
    this.scheduledDate,
    this.priority = 'medium',
    this.planName,
    required this.progress,
    required this.items,
  });

  factory CycleTargetsResponse.fromJson(Map<String, dynamic> json) {
    final session = (json['session'] as Map?) ?? {};
    return CycleTargetsResponse(
      sessionId: session['id'] ?? 0,
      warehouseCode: session['warehouse_code'] ?? '',
      warehouseName: session['warehouse_name'],
      countingType: session['counting_type'] ?? 'cycle',
      status: session['status'] ?? 'in_progress',
      scheduledDate: session['scheduled_date'],
      priority: session['priority'] ?? 'medium',
      planName: session['plan_name'],
      progress: CycleProgress.fromJson(Map<String, dynamic>.from((json['progress'] as Map?) ?? {})),
      items: ((json['items'] as List?) ?? [])
          .map((e) => CycleTargetItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
