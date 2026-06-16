// Models for the owner's Retail Dashboard (لوحة البيع بالتجزئة).
// Mirror the JSON returned by RetailDashboardController.

double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

class RevenueBlock {
  final double net;
  final double gross;
  final double returns;
  final int invoices;
  final double aov;

  RevenueBlock({
    required this.net,
    required this.gross,
    required this.returns,
    required this.invoices,
    this.aov = 0,
  });

  factory RevenueBlock.fromJson(Map<String, dynamic> j) => RevenueBlock(
        net: _d(j['net']),
        gross: _d(j['gross']),
        returns: _d(j['returns']),
        invoices: _i(j['invoices']),
        aov: _d(j['aov']),
      );
}

class ProfitBlock {
  final double profit; // ex-VAT SAR
  final double? marginPct;
  final bool estimated;

  ProfitBlock({required this.profit, this.marginPct, this.estimated = true});

  factory ProfitBlock.fromJson(Map<String, dynamic> j) => ProfitBlock(
        profit: _d(j['profit']),
        marginPct: j['margin_pct'] == null ? null : _d(j['margin_pct']),
        estimated: j['estimated'] != false,
      );

  static ProfitBlock empty() => ProfitBlock(profit: 0, marginPct: null);
}

class OpsCounts {
  final int qualityPending;
  final int countingActive;
  final int transfersNew;
  final int zooboxiPending;
  final int zooboxiUrgent;

  OpsCounts({
    required this.qualityPending,
    required this.countingActive,
    required this.transfersNew,
    required this.zooboxiPending,
    required this.zooboxiUrgent,
  });

  factory OpsCounts.fromJson(Map<String, dynamic> j) => OpsCounts(
        qualityPending: _i(j['quality_pending']),
        countingActive: _i(j['counting_active']),
        transfersNew: _i(j['transfers_new']),
        zooboxiPending: _i(j['zooboxi_pending']),
        zooboxiUrgent: _i(j['zooboxi_urgent']),
      );

  int get total => qualityPending + countingActive + transfersNew + zooboxiPending;
}

class BranchCard {
  final String code;
  final String name;
  final RevenueBlock revenue;
  final ProfitBlock profit;
  final double? score;
  final int? rank;
  final int? totalBranches;
  final double bleedingMonthlySar;
  final double trappedCapitalSar;
  final OpsCounts ops;

  BranchCard({
    required this.code,
    required this.name,
    required this.revenue,
    required this.profit,
    this.score,
    this.rank,
    this.totalBranches,
    required this.bleedingMonthlySar,
    required this.trappedCapitalSar,
    required this.ops,
  });

  factory BranchCard.fromJson(Map<String, dynamic> j) {
    final wh = Map<String, dynamic>.from(j['warehouse'] as Map? ?? {});
    return BranchCard(
      code: '${wh['code'] ?? ''}',
      name: '${wh['name'] ?? wh['code'] ?? ''}',
      revenue: RevenueBlock.fromJson(Map<String, dynamic>.from(j['revenue'] as Map? ?? {})),
      profit: j['profit'] is Map ? ProfitBlock.fromJson(Map<String, dynamic>.from(j['profit'] as Map)) : ProfitBlock.empty(),
      score: j['score'] == null ? null : _d(j['score']),
      rank: j['rank'] == null ? null : _i(j['rank']),
      totalBranches: j['total_branches'] == null ? null : _i(j['total_branches']),
      bleedingMonthlySar: _d(j['bleeding_monthly_sar']),
      trappedCapitalSar: _d(j['trapped_capital_sar']),
      ops: OpsCounts.fromJson(Map<String, dynamic>.from(j['ops'] as Map? ?? {})),
    );
  }
}

class RetailPeriod {
  final String key;
  final String from;
  final String to;
  RetailPeriod({required this.key, required this.from, required this.to});
  factory RetailPeriod.fromJson(Map<String, dynamic> j) =>
      RetailPeriod(key: '${j['key'] ?? 'month'}', from: '${j['from'] ?? ''}', to: '${j['to'] ?? ''}');
}

class RetailOverview {
  final RetailPeriod period;
  final double totalNet;
  final double totalProfit;
  final int totalInvoices;
  final int branchesCount;
  final SalesProfitTrend trend;
  final List<BranchCard> branches;

  RetailOverview({
    required this.period,
    required this.totalNet,
    required this.totalProfit,
    required this.totalInvoices,
    required this.branchesCount,
    required this.trend,
    required this.branches,
  });

  factory RetailOverview.fromJson(Map<String, dynamic> j) {
    final totals = Map<String, dynamic>.from(j['totals'] as Map? ?? {});
    return RetailOverview(
      period: RetailPeriod.fromJson(Map<String, dynamic>.from(j['period'] as Map? ?? {})),
      totalNet: _d(totals['net']),
      totalProfit: _d(totals['profit']),
      totalInvoices: _i(totals['invoices']),
      branchesCount: _i(totals['branches']),
      trend: j['trend'] is Map ? SalesProfitTrend.fromJson(Map<String, dynamic>.from(j['trend'] as Map)) : SalesProfitTrend.empty(),
      branches: ((j['branches'] as List?) ?? [])
          .map((e) => BranchCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class Vital {
  final String key;
  final double? value;
  final double? raw;
  Vital({required this.key, this.value, this.raw});
  factory Vital.fromJson(Map<String, dynamic> j) => Vital(
        key: '${j['key'] ?? ''}',
        value: j['value'] == null ? null : _d(j['value']),
        raw: j['raw'] == null ? null : _d(j['raw']),
      );
}

class LeverItem {
  final String itemCode;
  final String name;
  final String imageUrl;
  final String healthStatus;
  final double currentStock;
  final double primaryValue; // lost_revenue_monthly OR capital_at_risk_sar
  final String primaryLabelKey; // 'rd_bleeding' or 'rd_trapped'

  LeverItem({
    required this.itemCode,
    required this.name,
    required this.imageUrl,
    required this.healthStatus,
    required this.currentStock,
    required this.primaryValue,
    required this.primaryLabelKey,
  });

  factory LeverItem.bleeding(Map<String, dynamic> j) => LeverItem(
        itemCode: '${j['item_code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        imageUrl: '${j['image_url'] ?? ''}',
        healthStatus: '${j['health_status'] ?? ''}',
        currentStock: _d(j['current_stock']),
        primaryValue: _d(j['lost_revenue_monthly']),
        primaryLabelKey: 'rd_bleeding',
      );

  factory LeverItem.trapped(Map<String, dynamic> j) => LeverItem(
        itemCode: '${j['item_code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        imageUrl: '${j['image_url'] ?? ''}',
        healthStatus: '${j['health_status'] ?? ''}',
        currentStock: _d(j['current_stock']),
        primaryValue: _d(j['capital_at_risk_sar']),
        primaryLabelKey: 'rd_trapped',
      );
}

class TopProduct {
  final String itemCode;
  final String name;
  final String imageUrl;
  final double units;
  TopProduct({required this.itemCode, required this.name, required this.imageUrl, required this.units});
  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
        itemCode: '${j['item_code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        imageUrl: '${j['image_url'] ?? ''}',
        units: _d(j['units']),
      );
}

/// One bucket of the sales+profit time series (hour or day).
class TrendBucket {
  final String label;
  final double sales;
  final double profit;
  TrendBucket({required this.label, required this.sales, required this.profit});
  factory TrendBucket.fromJson(Map<String, dynamic> j) =>
      TrendBucket(label: '${j['label'] ?? ''}', sales: _d(j['sales']), profit: _d(j['profit']));
}

/// Combined sales + profit trend with its granularity ('hour' | 'day').
class SalesProfitTrend {
  final String granularity;
  final List<TrendBucket> points;
  SalesProfitTrend({required this.granularity, required this.points});

  factory SalesProfitTrend.fromJson(Map<String, dynamic> j) => SalesProfitTrend(
        granularity: '${j['granularity'] ?? 'day'}',
        points: ((j['points'] as List?) ?? [])
            .map((e) => TrendBucket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static SalesProfitTrend empty() => SalesProfitTrend(granularity: 'day', points: []);
  bool get isHourly => granularity == 'hour';
}

class BranchDetail {
  final String code;
  final String name;
  final RetailPeriod period;
  final RevenueBlock revenue;
  final ProfitBlock profit;
  final SalesProfitTrend trend;
  final List<TopProduct> topProducts;
  final double? score;
  final int? rank;
  final int? totalBranches;
  final List<Vital> vitals;
  final double bleedingTotal;
  final List<LeverItem> bleedingItems;
  final double trappedTotal;
  final List<LeverItem> trappedItems;
  final OpsCounts ops;

  BranchDetail({
    required this.code,
    required this.name,
    required this.period,
    required this.revenue,
    required this.profit,
    required this.trend,
    required this.topProducts,
    this.score,
    this.rank,
    this.totalBranches,
    required this.vitals,
    required this.bleedingTotal,
    required this.bleedingItems,
    required this.trappedTotal,
    required this.trappedItems,
    required this.ops,
  });

  factory BranchDetail.fromJson(Map<String, dynamic> j) {
    final wh = Map<String, dynamic>.from(j['warehouse'] as Map? ?? {});
    final score = j['score'] is Map ? Map<String, dynamic>.from(j['score'] as Map) : <String, dynamic>{};
    final levers = Map<String, dynamic>.from(j['levers'] as Map? ?? {});
    final bleeding = Map<String, dynamic>.from(levers['bleeding'] as Map? ?? {});
    final trapped = Map<String, dynamic>.from(levers['trapped'] as Map? ?? {});
    return BranchDetail(
      code: '${wh['code'] ?? ''}',
      name: '${wh['name'] ?? wh['code'] ?? ''}',
      period: RetailPeriod.fromJson(Map<String, dynamic>.from(j['period'] as Map? ?? {})),
      revenue: RevenueBlock.fromJson(Map<String, dynamic>.from(j['revenue'] as Map? ?? {})),
      profit: j['profit'] is Map ? ProfitBlock.fromJson(Map<String, dynamic>.from(j['profit'] as Map)) : ProfitBlock.empty(),
      trend: j['trend'] is Map ? SalesProfitTrend.fromJson(Map<String, dynamic>.from(j['trend'] as Map)) : SalesProfitTrend.empty(),
      topProducts: ((j['top_products'] as List?) ?? [])
          .map((e) => TopProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      score: score['value'] == null ? null : _d(score['value']),
      rank: score['rank'] == null ? null : _i(score['rank']),
      totalBranches: score['total_branches'] == null ? null : _i(score['total_branches']),
      vitals: ((j['vitals'] as List?) ?? [])
          .map((e) => Vital.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bleedingTotal: _d(bleeding['total_monthly_sar']),
      bleedingItems: ((bleeding['items'] as List?) ?? [])
          .map((e) => LeverItem.bleeding(Map<String, dynamic>.from(e as Map)))
          .toList(),
      trappedTotal: _d(trapped['total_sar']),
      trappedItems: ((trapped['items'] as List?) ?? [])
          .map((e) => LeverItem.trapped(Map<String, dynamic>.from(e as Map)))
          .toList(),
      ops: OpsCounts.fromJson(Map<String, dynamic>.from(j['ops'] as Map? ?? {})),
    );
  }
}
