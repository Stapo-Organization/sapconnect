import 'package:exhibition_manager_app/features/retail_dashboard/data/retail_dashboard_repository.dart';
import 'package:exhibition_manager_app/features/retail_dashboard/data/models/retail_models.dart';
import 'package:exhibition_manager_app/features/stock_distribution/data/stock_distribution_repository.dart';
import 'package:exhibition_manager_app/features/stock_distribution/data/models/distribution_models.dart';
import 'package:exhibition_manager_app/features/container_tracking/data/container_tracking_repository.dart';
import 'package:exhibition_manager_app/features/container_tracking/data/models/container_models.dart';
import 'package:exhibition_manager_app/features/quality_control/data/quality_admin_repository.dart';
import 'package:exhibition_manager_app/features/promotions/data/promotions_repository.dart';

import 'models/owner_command_models.dart';

/// مُجمِّع «مركز القيادة» — يستدعي المستودعات الخمسة القائمة بالتوازي ويبني
/// [OwnerCommandSnapshot] دون أي تغيير في الباكند. كل المصادر تُطلَق معاً ثم
/// يُنتظر كل واحد داخل try/catch مستقل، فلا يُسقِط فشلٌ واحد بقية اللوحة.
class OwnerCommandRepository {
  final RetailDashboardRepository _retail = RetailDashboardRepository();
  final StockDistributionRepository _dist = StockDistributionRepository();
  final ContainerTrackingRepository _containers = ContainerTrackingRepository();
  final QualityAdminRepository _quality = QualityAdminRepository();
  final PromotionsRepository _promos = PromotionsRepository();

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<OwnerCommandSnapshot> loadSnapshot() async {
    final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));

    // أطلق كل النداءات معاً (تبقى في الطيران) ثم انتظر كلاً منها بحراسة مستقلة.
    final fToday = _retail.getOverview(period: 'today', sort: 'revenue');
    final fPrev = _retail.getOverview(period: 'custom', from: yesterday, to: yesterday);
    final fPromos = _promos.getSummary();
    final fDist = _dist.getStatus();
    final fCont = _containers.getOverview(state: 'all');
    final fQa = _quality.getInstances(status: 'pending');

    RetailOverview? today;
    try {
      final r = await fToday;
      if (r.success) today = r.data;
    } catch (_) {}

    double? prevNet;
    try {
      final r = await fPrev;
      if (r.success && r.data != null) prevNet = r.data!.totalNet;
    } catch (_) {}

    bool promosOk = false;
    int promosPending = 0;
    try {
      final r = await fPromos;
      promosOk = r.success;
      promosPending = r.pendingCount;
    } catch (_) {}

    bool distOk = false;
    DistributionStatus? engine;
    try {
      final r = await fDist;
      distOk = r.success && r.status != null;
      engine = r.status;
    } catch (_) {}

    bool contOk = false;
    ContainerSummary? containers;
    try {
      final r = await fCont;
      contOk = r.success && r.data != null;
      containers = r.data?.summary;
    } catch (_) {}

    bool qaOk = false;
    int qaOverdue = 0;
    try {
      final r = await fQa;
      qaOk = r.success;
      qaOverdue = r.instances.where((e) => e.isOverdue).length;
    } catch (_) {}

    final retailOk = today != null;

    // الدلتا مقابل الأمس (إن توفّر الطرفان).
    double? delta;
    double? deltaPct;
    if (today != null && prevNet != null) {
      delta = today.totalNet - prevNet;
      deltaPct = prevNet > 0 ? (delta / prevNet) * 100 : null;
    }

    // روافع المال = مجموع الفروع.
    double bleeding = 0, trapped = 0;
    final branches = today?.branches ?? const <BranchCard>[];
    for (final b in branches) {
      bleeding += b.bleedingMonthlySar;
      trapped += b.trappedCapitalSar;
    }

    // أعلى الفروع بصافي المبيعات (لِلوحة الترتيب).
    final sorted = [...branches]..sort((a, b) => b.revenue.net.compareTo(a.revenue.net));
    final top = sorted.take(5).toList();
    final maxNet = sorted.isEmpty ? 0.0 : sorted.first.revenue.net;

    final profit = today?.totalProfit ?? 0;
    final net = today?.totalNet ?? 0;

    return OwnerCommandSnapshot(
      retailOk: retailOk,
      netSalesToday: net,
      netSalesDelta: delta,
      netSalesDeltaPct: deltaPct,
      totalProfit: profit,
      marginPct: (retailOk && net > 0) ? (profit / net) * 100 : null,
      totalInvoices: today?.totalInvoices ?? 0,
      branchesCount: today?.branchesCount ?? 0,
      totalBleeding: bleeding,
      totalTrapped: trapped,
      trend: today?.trend ?? SalesProfitTrend.empty(),
      topBranches: top,
      maxNet: maxNet,
      promosOk: promosOk,
      promosPending: promosPending,
      distributionOk: distOk,
      distributionPending: engine?.pendingCount ?? 0,
      qualityOk: qaOk,
      qualityOverdue: qaOverdue,
      containersOk: contOk,
      containersDelayed: containers?.attention ?? 0,
      engine: engine,
      containers: containers,
    );
  }
}
