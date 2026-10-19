/// Stock Transfer model
class StockTransfer {
  final int id;
  final String? docEntry;
  final String? docNum;
  /// A stock transfer SAP posted directly, with no request: only the receiving side acts.
  final bool isDirect;
  final String fromWarehouse;
  final String toWarehouse;
  final String? fromWarehouseNameAr;
  final String? fromWarehouseNameEn;
  final String? toWarehouseNameAr;
  final String? toWarehouseNameEn;
  final String? docDate;
  final double totalQty;
  final double totalSentQty;
  final double totalReceivedQty;
  final double sendingPercentage;
  final double receivingPercentage;
  /// Pieces SAP delivered against this request (stock transfers made in SAP).
  final double sapReceivedQty;
  final String? documentStatus;
  final String internalStatus;
  final Map<String, dynamic>? sentBy;
  final String? sentAt;
  final Map<String, dynamic>? receivedBy;
  final String? receivedAt;
  final String? senderNotes;
  final String? receiverNotes;
  final bool canSend;
  final bool canReceive;
  final bool isOutgoing;
  final bool isIncoming;
  final int linesCount;
  final List<String> images;
  final List<StockTransferLine> lines;

  StockTransfer({
    required this.id,
    this.docEntry,
    this.docNum,
    this.isDirect = false,
    required this.fromWarehouse,
    required this.toWarehouse,
    this.fromWarehouseNameAr,
    this.fromWarehouseNameEn,
    this.toWarehouseNameAr,
    this.toWarehouseNameEn,
    this.docDate,
    required this.totalQty,
    required this.totalSentQty,
    required this.totalReceivedQty,
    required this.sendingPercentage,
    required this.receivingPercentage,
    this.sapReceivedQty = 0,
    this.documentStatus,
    required this.internalStatus,
    this.sentBy,
    this.sentAt,
    this.receivedBy,
    this.receivedAt,
    this.senderNotes,
    this.receiverNotes,
    required this.canSend,
    required this.canReceive,
    this.isOutgoing = false,
    this.isIncoming = false,
    this.linesCount = 0,
    required this.images,
    required this.lines,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'] ?? 0,
      docEntry: json['doc_entry']?.toString(),
      docNum: json['doc_num']?.toString(),
      isDirect: json['is_direct'] == true,
      fromWarehouse: json['from_warehouse'] ?? '',
      toWarehouse: json['to_warehouse'] ?? '',
      fromWarehouseNameAr: json['from_warehouse_name_ar'],
      fromWarehouseNameEn: json['from_warehouse_name_en'],
      toWarehouseNameAr: json['to_warehouse_name_ar'],
      toWarehouseNameEn: json['to_warehouse_name_en'],
      docDate: json['doc_date'],
      totalQty: (json['total_qty'] ?? 0).toDouble(),
      totalSentQty: (json['total_sent_qty'] ?? 0).toDouble(),
      totalReceivedQty: (json['total_received_qty'] ?? 0).toDouble(),
      sendingPercentage: (json['sending_percentage'] ?? 0).toDouble(),
      receivingPercentage: (json['receiving_percentage'] ?? 0).toDouble(),
      sapReceivedQty: (json['sap_received_qty'] ?? 0).toDouble(),
      documentStatus: json['document_status'],
      internalStatus: json['internal_status'] ?? 'New',
      sentBy: json['sent_by'] is Map ? json['sent_by'] : null,
      sentAt: json['sent_at'],
      receivedBy: json['received_by'] is Map ? json['received_by'] : null,
      receivedAt: json['received_at'],
      senderNotes: json['sender_notes'],
      receiverNotes: json['receiver_notes'],
      canSend: json['can_send'] ?? false,
      canReceive: json['can_receive'] ?? false,
      isOutgoing: json['is_outgoing'] ?? false,
      isIncoming: json['is_incoming'] ?? false,
      linesCount: json['lines_count'] ?? (json['lines'] as List?)?.length ?? 0,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lines: (json['lines'] as List?)
              ?.map((e) => StockTransferLine.fromJson(e))
              .toList() ??
          [],
    );
  }
}

extension StockTransferNames on StockTransfer {
  /// The branch's name in the app's language, else its SAP code.
  String fromName(bool arabic) => (arabic ? fromWarehouseNameAr : fromWarehouseNameEn) ?? fromWarehouse;
  String toName(bool arabic) => (arabic ? toWarehouseNameAr : toWarehouseNameEn) ?? toWarehouse;
}

/// Stock Transfer Line model
class StockTransferLine {
  final int id;
  final String itemCode;
  final String? itemDescription;
  final String? itemNameAr;
  final String? itemNameEn;
  final double quantity;
  final double sentQuantity;
  final double actualReceivedQuantity;
  final double remainingQuantity;
  final double receivingPercentage;
  /// What SAP delivered on this line.
  final double sapReceivedQuantity;
  final String? lineStatus;

  StockTransferLine({
    required this.id,
    required this.itemCode,
    this.itemDescription,
    this.itemNameAr,
    this.itemNameEn,
    required this.quantity,
    required this.sentQuantity,
    required this.actualReceivedQuantity,
    required this.remainingQuantity,
    required this.receivingPercentage,
    this.sapReceivedQuantity = 0,
    this.lineStatus,
  });

  factory StockTransferLine.fromJson(Map<String, dynamic> json) {
    return StockTransferLine(
      id: json['id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemDescription: json['item_description'],
      itemNameAr: json['item_name_ar'],
      itemNameEn: json['item_name_en'],
      quantity: (json['quantity'] ?? 0).toDouble(),
      sentQuantity: (json['sent_quantity'] ?? 0).toDouble(),
      actualReceivedQuantity: (json['actual_received_quantity'] ?? 0).toDouble(),
      remainingQuantity: (json['remaining_quantity'] ?? 0).toDouble(),
      receivingPercentage: (json['receiving_percentage'] ?? 0).toDouble(),
      sapReceivedQuantity: (json['received_quantity'] ?? 0).toDouble(),
      lineStatus: json['line_status'],
    );
  }

  /// Get product image URL
  String get imageUrl {
    final folder = itemCode.length >= 4 ? itemCode.substring(0, 4) : itemCode;
    return 'https://ppte.sa/img/$folder/$itemCode.png';
  }

  /// Get Localized Name
  String getLocalizedName(bool isArabic) {
    if (isArabic) {
      return itemNameAr ?? itemDescription ?? itemCode;
    } else {
      return itemNameEn ?? itemDescription ?? itemCode;
    }
  }
}
