// Models for Smart Stock Distribution (التوزيع الذكي للمخزون).

double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

class DistributionStatus {
  final bool running;
  final String? lastComputedAt;
  final int pendingCount;
  DistributionStatus({required this.running, this.lastComputedAt, required this.pendingCount});
  factory DistributionStatus.fromJson(Map<String, dynamic> j) => DistributionStatus(
        running: j['running'] == true,
        lastComputedAt: j['last_computed_at']?.toString(),
        pendingCount: _i(j['pending_count']),
      );
}

class SuggestionItem {
  final int id;
  final String itemCode;
  final String name;
  final String imageUrl;
  final int suggestedQuantity;
  final double sourceStock;
  final double targetStock;
  final double targetAds;

  SuggestionItem({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.imageUrl,
    required this.suggestedQuantity,
    required this.sourceStock,
    required this.targetStock,
    required this.targetAds,
  });

  factory SuggestionItem.fromJson(Map<String, dynamic> j) => SuggestionItem(
        id: _i(j['id']),
        itemCode: '${j['item_code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        imageUrl: '${j['image_url'] ?? ''}',
        suggestedQuantity: _i(j['suggested_quantity']),
        sourceStock: _d(j['source_stock']),
        targetStock: _d(j['target_stock']),
        targetAds: _d(j['target_ads']),
      );
}

class DistributionLane {
  final String sourceCode;
  final String sourceName;
  final String targetCode;
  final String targetName;
  final String transferType; // central | cross_dock
  final int totalUnits;
  final List<SuggestionItem> items;

  DistributionLane({
    required this.sourceCode,
    required this.sourceName,
    required this.targetCode,
    required this.targetName,
    required this.transferType,
    required this.totalUnits,
    required this.items,
  });

  factory DistributionLane.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['source'] as Map? ?? {});
    final t = Map<String, dynamic>.from(j['target'] as Map? ?? {});
    return DistributionLane(
      sourceCode: '${s['code'] ?? ''}',
      sourceName: '${s['name'] ?? s['code'] ?? ''}',
      targetCode: '${t['code'] ?? ''}',
      targetName: '${t['name'] ?? t['code'] ?? ''}',
      transferType: '${j['transfer_type'] ?? 'cross_dock'}',
      totalUnits: _i(j['total_units']),
      items: ((j['items'] as List?) ?? [])
          .map((e) => SuggestionItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class DistributionOverview {
  final DistributionStatus status;
  final int totalLanes;
  final List<DistributionLane> lanes;
  DistributionOverview({required this.status, required this.totalLanes, required this.lanes});
  factory DistributionOverview.fromJson(Map<String, dynamic> j) => DistributionOverview(
        status: DistributionStatus.fromJson(Map<String, dynamic>.from(j['status'] as Map? ?? {})),
        totalLanes: _i(j['total_lanes']),
        lanes: ((j['groups'] as List?) ?? [])
            .map((e) => DistributionLane.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
