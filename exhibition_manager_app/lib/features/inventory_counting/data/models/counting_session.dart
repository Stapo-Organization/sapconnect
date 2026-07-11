import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Counting Session model
class CountingSession {
  final int id;
  final String warehouseCode;
  final String? warehouseName;
  final String status;
  final String countingType;
  final String priority;
  final String? scheduledDate;
  final int totalTargetItems;
  final Map<String, dynamic>? countedBy;
  final String? notes;
  final int linesCount;
  final double totalCountedQty;
  final String? createdAt;
  final String? completedAt;
  final List<CountingLine> lines;

  CountingSession({
    required this.id,
    required this.warehouseCode,
    this.warehouseName,
    required this.status,
    this.countingType = 'full',
    this.priority = 'medium',
    this.scheduledDate,
    this.totalTargetItems = 0,
    this.countedBy,
    this.notes,
    required this.linesCount,
    required this.totalCountedQty,
    this.createdAt,
    this.completedAt,
    required this.lines,
  });

  factory CountingSession.fromJson(Map<String, dynamic> json) {
    return CountingSession(
      id: json['id'] ?? 0,
      warehouseCode: json['warehouse_code'] ?? '',
      warehouseName: json['warehouse_name'],
      status: json['status'] ?? 'in_progress',
      countingType: json['counting_type'] ?? 'full',
      priority: json['priority'] ?? 'medium',
      scheduledDate: json['scheduled_date'],
      totalTargetItems: json['total_target_items'] ?? 0,
      countedBy: json['counted_by'] is Map ? json['counted_by'] : null,
      notes: json['notes'],
      linesCount: json['lines_count'] ?? 0,
      totalCountedQty: (json['total_counted_qty'] ?? 0).toDouble(),
      createdAt: json['created_at'],
      completedAt: json['completed_at'],
      lines: (json['lines'] as List?)
              ?.map((e) => CountingLine.fromJson(e))
              .toList() ??
          [],
    );
  }

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isCycleCount => countingType == 'cycle';

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return AppLocalizations.translate('counting_in_progress');
      case 'completed':
        return AppLocalizations.translate('status_completed');
      case 'cancelled':
        return AppLocalizations.translate('status_cancelled');
      default:
        return status;
    }
  }

  String get countingTypeLabel {
    switch (countingType) {
      case 'cycle':
        return AppLocalizations.translate('cycle_count');
      default:
        return AppLocalizations.translate('full_count');
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'high':
        return AppLocalizations.translate('ic_priority_high');
      case 'low':
        return AppLocalizations.translate('ic_priority_low');
      default:
        return AppLocalizations.translate('ic_priority_medium');
    }
  }
}

/// Counting Line model
class CountingLine {
  final int id;
  final String itemCode;
  final String? itemName;
  final String? itemNameAr;
  final String? itemNameEn;
  final String? pieceBarcode;
  final double countedQuantity;
  final double systemQuantity;
  final double variance;
  final double variancePercentage;
  final String varianceStatus;
  final String? investigationNote;
  final String? imageUrl;
  final String? createdAt;

  CountingLine({
    required this.id,
    required this.itemCode,
    this.itemName,
    this.itemNameAr,
    this.itemNameEn,
    this.pieceBarcode,
    required this.countedQuantity,
    this.systemQuantity = 0,
    this.variance = 0,
    this.variancePercentage = 0,
    this.varianceStatus = 'uncounted',
    this.investigationNote,
    this.imageUrl,
    this.createdAt,
  });

  factory CountingLine.fromJson(Map<String, dynamic> json) {
    return CountingLine(
      id: json['id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'],
      itemNameAr: json['item_name_ar'],
      itemNameEn: json['item_name_en'],
      pieceBarcode: json['piece_barcode'],
      countedQuantity: (json['counted_quantity'] ?? 0).toDouble(),
      systemQuantity: (json['system_quantity'] ?? 0).toDouble(),
      variance: (json['variance'] ?? 0).toDouble(),
      variancePercentage: (json['variance_percentage'] ?? 0).toDouble(),
      varianceStatus: json['variance_status'] ?? 'uncounted',
      investigationNote: json['investigation_note'],
      imageUrl: json['image_url'],
      createdAt: json['created_at'],
    );
  }

  /// Get Localized Name
  String getLocalizedName(bool isArabic) {
    if (isArabic) {
      return itemNameAr ?? itemName ?? itemCode;
    } else {
      return itemNameEn ?? itemName ?? itemCode;
    }
  }

  bool get hasVariance => varianceStatus != 'match' && varianceStatus != 'uncounted' && varianceStatus != 'within_tolerance';
  bool get isMatch => varianceStatus == 'match';
  bool get isWithinTolerance => varianceStatus == 'within_tolerance';
  bool get isOver => varianceStatus == 'over';
  bool get isShort => varianceStatus == 'short';

  String get varianceStatusLabel {
    switch (varianceStatus) {
      case 'match': return AppLocalizations.translate('ic_variance_match');
      case 'within_tolerance': return AppLocalizations.translate('ic_variance_within_tolerance');
      case 'over': return AppLocalizations.translate('ic_variance_over');
      case 'short': return AppLocalizations.translate('ic_variance_short');
      case 'not_in_system': return AppLocalizations.translate('ic_variance_not_in_system');
      default: return AppLocalizations.translate('ic_variance_uncounted');
    }
  }
}

/// Scanned Product (from barcode scan response)
class ScannedProduct {
  final String itemCode;
  final String itemName;
  final String? itemNameAr;
  final String? itemNameEn;
  final String? pieceBarcode;
  final String imageUrl;
  final CountingLine? existingLine;

  /// Cycle-count gating: whether this item is part of the session's target
  /// list. `null` for full counts (which accept any product).
  final bool? inTargetList;

  /// ABC class of the target item (cycle only, else null).
  final String? abcClass;

  ScannedProduct({
    required this.itemCode,
    required this.itemName,
    this.itemNameAr,
    this.itemNameEn,
    this.pieceBarcode,
    required this.imageUrl,
    this.existingLine,
    this.inTargetList,
    this.abcClass,
  });

  factory ScannedProduct.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    final existing = json['existing_line'];

    return ScannedProduct(
      itemCode: product['item_code'] ?? '',
      itemName: product['item_name'] ?? '',
      itemNameAr: product['item_name_ar'],
      itemNameEn: product['item_name_en'],
      pieceBarcode: product['piece_barcode'],
      imageUrl: product['image_url'] ?? '',
      existingLine: existing != null
          ? CountingLine(
              id: existing['id'] ?? 0,
              itemCode: product['item_code'] ?? '',
              countedQuantity: (existing['counted_quantity'] ?? 0).toDouble(),
            )
          : null,
      inTargetList: json['in_target_list'] as bool?,
      abcClass: json['abc_class'] as String?,
    );
  }

  /// Get Localized Name
  String getLocalizedName(bool isArabic) {
    if (isArabic) {
      return itemNameAr ?? itemName ?? itemCode;
    } else {
      return itemNameEn ?? itemName ?? itemCode;
    }
  }
}
