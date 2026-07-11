import 'package:exhibition_manager_app/features/retail_dashboard/data/models/retail_models.dart';
import 'package:exhibition_manager_app/features/stock_distribution/data/models/distribution_models.dart';
import 'package:exhibition_manager_app/features/container_tracking/data/models/container_models.dart';

/// لقطة «مركز القيادة» المُجمَّعة — تُبنى في الدارت من عدّة مصادر متوازية
/// (لا تأتي من نقطة نهاية واحدة)، فكل مصدر له عَلَم نجاح مستقل حتى تبقى اللوحة
/// قابلة للعرض جزئياً عند فشل أحد المصادر.
class OwnerCommandSnapshot {
  // ─── البطل: شبكة المبيعات اليوم ───
  final bool retailOk;
  final double netSalesToday;
  final double? netSalesDelta; // اليوم − الأمس (null إذا تعذّر حساب الأمس)
  final double? netSalesDeltaPct;
  final double totalProfit;
  final double? marginPct;
  final int totalInvoices;
  final int branchesCount;

  // ─── روافع المال عبر الشبكة ───
  final double totalBleeding; // Σ نزيف الفروع الشهري
  final double totalTrapped; // Σ رأس المال المحتجز

  // ─── الرسم البياني + ترتيب الفروع ───
  final SalesProfitTrend trend;
  final List<BranchCard> topBranches;
  final double maxNet;

  // ─── تقسيم القنوات (معارض/جملة/إجمالي) — null على سيرفر قديم ───
  final ChannelSplit? channelsToday;
  final double? retailDelta;
  final double? retailDeltaPct;
  final double? wholesaleDelta;
  final double? wholesaleDeltaPct;

  // ─── طابور القرارات ───
  final bool promosOk;
  final int promosPending;
  final bool distributionOk;
  final int distributionPending;
  final bool qualityOk;
  final int qualityOverdue;
  final bool containersOk;
  final int containersDelayed;

  // ─── شرائط الحالة ───
  final DistributionStatus? engine;
  final ContainerSummary? containers;

  OwnerCommandSnapshot({
    required this.retailOk,
    required this.netSalesToday,
    required this.netSalesDelta,
    required this.netSalesDeltaPct,
    required this.totalProfit,
    required this.marginPct,
    required this.totalInvoices,
    required this.branchesCount,
    required this.totalBleeding,
    required this.totalTrapped,
    required this.trend,
    required this.topBranches,
    required this.maxNet,
    this.channelsToday,
    this.retailDelta,
    this.retailDeltaPct,
    this.wholesaleDelta,
    this.wholesaleDeltaPct,
    required this.promosOk,
    required this.promosPending,
    required this.distributionOk,
    required this.distributionPending,
    required this.qualityOk,
    required this.qualityOverdue,
    required this.containersOk,
    required this.containersDelayed,
    required this.engine,
    required this.containers,
  });

  /// هل نملك تقسيم القنوات؟ (سيرفر مُحدَّث) — وإلا نعود لتخطيط الرقم الواحد.
  bool get hasChannels => channelsToday != null;

  /// إجمالي ما ينتظر قرار المالك عبر كل المصادر.
  int get pendingDecisions =>
      promosPending + distributionPending + qualityOverdue + containersDelayed;

  /// هل فشلت كل المصادر؟ (نعرض عندها خطأً كاملاً مع إعادة المحاولة.)
  bool get allFailed =>
      !retailOk && !promosOk && !distributionOk && !qualityOk && !containersOk;
}
