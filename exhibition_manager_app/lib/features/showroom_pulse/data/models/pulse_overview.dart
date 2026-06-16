// Models for نبض المعرض (Showroom Pulse) — mirror of the
// GET /showroom-pulse payload (score + vitals + the three money levers).

double _d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
double? _dn(dynamic v) => (v is num) ? v.toDouble() : null;
int _i(dynamic v) => (v is num) ? v.toInt() : 0;
int? _in(dynamic v) => (v is num) ? v.toInt() : null;
String? _s(dynamic v) => v?.toString();

class WarehouseRef {
  final String code;
  final String name;
  final String? imageUrl;

  WarehouseRef({required this.code, required this.name, this.imageUrl});

  factory WarehouseRef.fromJson(Map<String, dynamic> j) => WarehouseRef(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        imageUrl: _s(j['image_url']),
      );
}

class PulseScore {
  final double value;
  final double? prev;
  final double? trend;
  final int? rank;
  final int? totalBranches;

  PulseScore({required this.value, this.prev, this.trend, this.rank, this.totalBranches});

  factory PulseScore.fromJson(Map<String, dynamic> j) => PulseScore(
        value: _d(j['value']),
        prev: _dn(j['prev']),
        trend: _dn(j['trend']),
        rank: _in(j['rank']),
        totalBranches: _in(j['total_branches']),
      );
}

class PulseVital {
  final String key;
  final double? value; // 0..100; null = no data yet (e.g. not cycle-counted)
  final double? raw;   // raw figure for display (basket items/invoice)

  PulseVital({required this.key, this.value, this.raw});

  factory PulseVital.fromJson(Map<String, dynamic> j) =>
      PulseVital(key: (j['key'] ?? '').toString(), value: _dn(j['value']), raw: _dn(j['raw']));
}

/// 🔴 أوقف النزيف
class BleedingItem {
  final String itemCode;
  final String name;
  final String? barcode;
  final String imageUrl;
  final String healthStatus;
  final double currentStock; // this branch
  final double totalStock;   // all warehouses (network-wide)
  final double velocity;
  final double? daysOfCover;
  final double lostSalesMonthly;
  final double lostRevenueMonthly;

  BleedingItem({
    required this.itemCode,
    required this.name,
    required this.barcode,
    required this.imageUrl,
    required this.healthStatus,
    required this.currentStock,
    required this.totalStock,
    required this.velocity,
    required this.daysOfCover,
    required this.lostSalesMonthly,
    required this.lostRevenueMonthly,
  });

  factory BleedingItem.fromJson(Map<String, dynamic> j) => BleedingItem(
        itemCode: (j['item_code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        barcode: _s(j['barcode']),
        imageUrl: (j['image_url'] ?? '').toString(),
        healthStatus: (j['health_status'] ?? '').toString(),
        currentStock: _d(j['current_stock']),
        totalStock: _d(j['total_stock']),
        velocity: _d(j['velocity_blended']),
        daysOfCover: _dn(j['days_of_cover']),
        lostSalesMonthly: _d(j['lost_sales_monthly']),
        lostRevenueMonthly: _d(j['lost_revenue_monthly']),
      );
}

class BleedingLever {
  final double totalMonthlySar;
  final int totalCount;
  final List<BleedingItem> items;

  BleedingLever({required this.totalMonthlySar, required this.totalCount, required this.items});

  factory BleedingLever.fromJson(Map<String, dynamic> j) => BleedingLever(
        totalMonthlySar: _d(j['total_monthly_sar']),
        totalCount: _i(j['total_count']),
        items: ((j['items'] as List?) ?? [])
            .map((e) => BleedingItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// 🟡 حرّر فلوسك
class TrappedItem {
  final String itemCode;
  final String name;
  final String? barcode;
  final String imageUrl;
  final String healthStatus;
  final double currentStock;
  final double committed;      // reserved by open sales orders
  final double available;      // stock − committed (the only part that can be idle)
  final double velocity;       // blended calendar daily sales (for display)
  final double demandRate;     // stockout-robust demand rate (drives cover/excess)
  final double? daysOfCover;
  final double excessUnits;    // available units beyond the target coverage
  final int? stagnationDays;
  final double capitalAtRiskSar;
  final double valueRatioPct;  // share of the branch's total trapped capital

  TrappedItem({
    required this.itemCode,
    required this.name,
    required this.barcode,
    required this.imageUrl,
    required this.healthStatus,
    required this.currentStock,
    required this.committed,
    required this.available,
    required this.velocity,
    required this.demandRate,
    required this.daysOfCover,
    required this.excessUnits,
    required this.stagnationDays,
    required this.capitalAtRiskSar,
    required this.valueRatioPct,
  });

  /// Days the *available* stock lasts at the stockout-robust demand rate
  /// (null if there's no demand signal at all).
  double? get coverAvailable => demandRate > 0 ? available / demandRate : null;

  factory TrappedItem.fromJson(Map<String, dynamic> j) => TrappedItem(
        itemCode: (j['item_code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        barcode: _s(j['barcode']),
        imageUrl: (j['image_url'] ?? '').toString(),
        healthStatus: (j['health_status'] ?? '').toString(),
        currentStock: _d(j['current_stock']),
        committed: _d(j['committed']),
        available: _d(j['available']),
        velocity: _d(j['velocity_blended']),
        demandRate: _d(j['demand_rate']),
        daysOfCover: _dn(j['days_of_cover']),
        excessUnits: _d(j['excess_units']),
        stagnationDays: _in(j['stagnation_days']),
        capitalAtRiskSar: _d(j['capital_at_risk_sar']),
        valueRatioPct: _d(j['value_ratio_pct']),
      );
}

class TrappedLever {
  final double totalSar;
  final int totalCount;
  final List<TrappedItem> items;

  TrappedLever({required this.totalSar, required this.totalCount, required this.items});

  factory TrappedLever.fromJson(Map<String, dynamic> j) => TrappedLever(
        totalSar: _d(j['total_sar']),
        totalCount: _i(j['total_count']),
        items: ((j['items'] as List?) ?? [])
            .map((e) => TrappedItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// 🟢 كبّر السلة
class BasketPair {
  final WarehouseRef itemA; // reuses {code,name,image_url}
  final WarehouseRef itemB;
  final double lift;
  final double confidence;
  final int coCount;

  BasketPair({
    required this.itemA,
    required this.itemB,
    required this.lift,
    required this.confidence,
    required this.coCount,
  });

  factory BasketPair.fromJson(Map<String, dynamic> j) => BasketPair(
        itemA: WarehouseRef.fromJson(Map<String, dynamic>.from((j['item_a'] ?? {}) as Map)),
        itemB: WarehouseRef.fromJson(Map<String, dynamic>.from((j['item_b'] ?? {}) as Map)),
        lift: _d(j['lift']),
        confidence: _d(j['confidence']),
        coCount: _i(j['co_count']),
      );
}

class PulseOverview {
  final WarehouseRef warehouse;
  final List<WarehouseRef> availableWarehouses;
  final PulseScore? score;
  final List<PulseVital> vitals;
  final BleedingLever bleeding;
  final TrappedLever trapped;
  final List<BasketPair> basket;
  final int basketTotalCount;

  PulseOverview({
    required this.warehouse,
    required this.availableWarehouses,
    required this.score,
    required this.vitals,
    required this.bleeding,
    required this.trapped,
    required this.basket,
    required this.basketTotalCount,
  });

  factory PulseOverview.fromJson(Map<String, dynamic> json) {
    final levers = Map<String, dynamic>.from((json['levers'] ?? {}) as Map);
    final basketLever = Map<String, dynamic>.from((levers['basket'] ?? {}) as Map);
    return PulseOverview(
      warehouse: WarehouseRef.fromJson(Map<String, dynamic>.from((json['warehouse'] ?? {}) as Map)),
      availableWarehouses: ((json['available_warehouses'] as List?) ?? [])
          .map((e) => WarehouseRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      score: json['score'] != null
          ? PulseScore.fromJson(Map<String, dynamic>.from(json['score'] as Map))
          : null,
      vitals: ((json['vitals'] as List?) ?? [])
          .map((e) => PulseVital.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bleeding: BleedingLever.fromJson(Map<String, dynamic>.from((levers['bleeding'] ?? {}) as Map)),
      trapped: TrappedLever.fromJson(Map<String, dynamic>.from((levers['trapped'] ?? {}) as Map)),
      basket: ((basketLever['items'] as List?) ?? [])
          .map((e) => BasketPair.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      basketTotalCount: _i(basketLever['total_count']),
    );
  }
}
