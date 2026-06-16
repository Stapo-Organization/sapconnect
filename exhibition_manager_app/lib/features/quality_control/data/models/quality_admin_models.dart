// Models for owner-side Quality Tasks management (إدارة مهام الجودة).

int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

class QualityTemplate {
  final int id;
  final String title;
  final String warehouseCode;
  final String warehouseName;
  final String proofType; // acknowledge | photo | checklist
  final String recurrence; // once | daily | weekly
  final String priority; // high | medium | low
  final bool isActive;
  final int pendingCount;
  final int submittedCount;
  final int overdueCount;

  QualityTemplate({
    required this.id,
    required this.title,
    required this.warehouseCode,
    required this.warehouseName,
    required this.proofType,
    required this.recurrence,
    required this.priority,
    required this.isActive,
    required this.pendingCount,
    required this.submittedCount,
    required this.overdueCount,
  });

  factory QualityTemplate.fromJson(Map<String, dynamic> j) => QualityTemplate(
        id: _i(j['id']),
        title: '${j['title'] ?? ''}',
        warehouseCode: '${j['warehouse_code'] ?? ''}',
        warehouseName: '${j['warehouse_name'] ?? j['warehouse_code'] ?? ''}',
        proofType: '${j['proof_type'] ?? 'photo'}',
        recurrence: '${j['recurrence'] ?? 'daily'}',
        priority: '${j['priority'] ?? 'medium'}',
        isActive: j['is_active'] == true,
        pendingCount: _i(j['pending_count']),
        submittedCount: _i(j['submitted_count']),
        overdueCount: _i(j['overdue_count']),
      );
}

class QualityInstanceRow {
  final int id;
  final String title;
  final String warehouseCode;
  final String warehouseName;
  final String status; // pending | submitted | cancelled
  final String priority;
  final String? scheduledDate;
  final bool isOverdue;

  QualityInstanceRow({
    required this.id,
    required this.title,
    required this.warehouseCode,
    required this.warehouseName,
    required this.status,
    required this.priority,
    this.scheduledDate,
    required this.isOverdue,
  });

  factory QualityInstanceRow.fromJson(Map<String, dynamic> j) => QualityInstanceRow(
        id: _i(j['id']),
        title: '${j['title'] ?? ''}',
        warehouseCode: '${j['warehouse_code'] ?? ''}',
        warehouseName: '${j['warehouse_name'] ?? j['warehouse_code'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        priority: '${j['priority'] ?? 'medium'}',
        scheduledDate: j['scheduled_date']?.toString(),
        isOverdue: j['is_overdue'] == true,
      );
}

class WarehouseRef {
  final String code;
  final String name;
  WarehouseRef({required this.code, required this.name});
  factory WarehouseRef.fromJson(Map<String, dynamic> j) =>
      WarehouseRef(code: '${j['warehouse_code'] ?? ''}', name: '${j['warehouse_name'] ?? j['warehouse_code'] ?? ''}');
}
