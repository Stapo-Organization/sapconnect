/// Muntajat Exhibition Manager — API Endpoints
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://sapapi.muntajat.sa/api';

  // ─── Auth ──────────────────────────────────────────────────
  static const String login = '$baseUrl/login';
  static const String verifyOtp = '$baseUrl/verify-otp';
  static const String logout = '$baseUrl/logout';
  static const String profile = '$baseUrl/profile';

  // ─── Public (pre-login landing) ────────────────────────────
  static const String landing = '$baseUrl/store/landing';
  static String brandDetail(String code) =>
      '$baseUrl/store/brands/${Uri.encodeComponent(code)}';

  // ─── Notifications (push token + channel preferences) ──────
  static const String fcmToken = '$baseUrl/profile/fcm-token';
  static const String notificationPreferences = '$baseUrl/profile/notification-preferences';

  // ─── Stock Transfers ───────────────────────────────────────
  static const String stockTransfers = '$baseUrl/stock-transfers';
  static String stockTransfer(int id) => '$baseUrl/stock-transfers/$id';
  static String sendItems(int id) => '$baseUrl/stock-transfers/$id/send-items';
  static String confirmSend(int id) => '$baseUrl/stock-transfers/$id/confirm-send';
  static String receiveItems(int id) => '$baseUrl/stock-transfers/$id/receive-items';
  static String confirmReceive(int id) => '$baseUrl/stock-transfers/$id/confirm-receive';
  static String transferLogs(int id) => '$baseUrl/stock-transfers/$id/logs';

  // ─── Inventory Counting ────────────────────────────────────
  static const String inventoryCountings = '$baseUrl/inventory-countings';
  static String inventoryCounting(int id) => '$baseUrl/inventory-countings/$id';
  static String countingScan(int id) => '$baseUrl/inventory-countings/$id/scan';
  static String countingLines(int id) => '$baseUrl/inventory-countings/$id/lines';
  static String countingLine(int id, int lineId) => '$baseUrl/inventory-countings/$id/lines/$lineId';
  static String countingComplete(int id) => '$baseUrl/inventory-countings/$id/complete';
  static String countingCancel(int id) => '$baseUrl/inventory-countings/$id/cancel';

  // ─── Cycle Counting ────────────────────────────────────────
  static const String countingSchedule = '$baseUrl/inventory-countings/schedule';
  static String countingTargets(int id) => '$baseUrl/inventory-countings/$id/targets';
  static String countingVarianceReport(int id) => '$baseUrl/inventory-countings/$id/variance-report';
  static String countingInvestigate(int id, int lineId) => '$baseUrl/inventory-countings/$id/lines/$lineId/investigate';
  static String countingAbcSummary(String warehouseCode) => '$baseUrl/inventory-countings/abc-summary/$warehouseCode';
  static String countingCycleProgress(String warehouseCode) => '$baseUrl/inventory-countings/cycle-progress/$warehouseCode';

  // ─── Products ──────────────────────────────────────────────
  static String productByBarcode(String barcode) => '$baseUrl/products/barcode/$barcode';
  static const String productSearch = '$baseUrl/products/search';
  static String productDetail(String itemCode) =>
      '$baseUrl/products/${Uri.encodeComponent(itemCode)}/detail';

  // ─── Warehouses ────────────────────────────────────────────
  // ─── Gamification ──────────────────────────────────────────
  static const String gamificationMe = '$baseUrl/gamification/me';
  static const String gamificationBadges = '$baseUrl/gamification/badges';
  static String gamificationLeaderboard(String type, String period) =>
      '$baseUrl/gamification/leaderboard?type=$type&period=$period';

  static const String warehouses = '$baseUrl/warehouses';

  // ─── Dashboard Stats ──────────────────────────────────────
  static const String dashboardStats = '$baseUrl/dashboard-stats';

  // ─── Home Dashboard (smart aggregation) ───────────────────
  static const String homeOverview = '$baseUrl/home/overview';

  // ─── Quality Control ───────────────────────────────────────
  static const String qualityTasks = '$baseUrl/quality-tasks';
  static const String qualityTasksSummary = '$baseUrl/quality-tasks/summary';
  static String qualityTask(int id) => '$baseUrl/quality-tasks/$id';
  static String qualityTaskPhotos(int id) => '$baseUrl/quality-tasks/$id/photos';
  static String qualityTaskPhoto(int id, int photoId) => '$baseUrl/quality-tasks/$id/photos/$photoId';
  static String qualityTaskSubmit(int id) => '$baseUrl/quality-tasks/$id/submit';

  // ─── Zooboxi Express Orders ────────────────────────────────
  static const String zooboxiOrders = '$baseUrl/zooboxi-orders';
  static const String zooboxiOrdersSummary = '$baseUrl/zooboxi-orders/summary';
  static String zooboxiOrder(int id) => '$baseUrl/zooboxi-orders/$id';
  static String zooboxiOrderStart(int id) => '$baseUrl/zooboxi-orders/$id/start';
  static String zooboxiOrderPrepare(int id) => '$baseUrl/zooboxi-orders/$id/prepare';

  // ─── Promotions / Ad Campaigns (owner only) ────────────────
  static const String promotions = '$baseUrl/promotions';
  static const String promotionsSummary = '$baseUrl/promotions/summary';
  static const String promotionsPlacements = '$baseUrl/promotions/placements';
  static String promotion(int id) => '$baseUrl/promotions/$id';
  static String promotionApprove(int id) => '$baseUrl/promotions/$id/approve';
  static String promotionPublish(int id) => '$baseUrl/promotions/$id/publish';
  static String promotionReject(int id) => '$baseUrl/promotions/$id/reject';
  static String promotionRegenerate(int id) => '$baseUrl/promotions/$id/regenerate';
  static String promotionRefine(int id) => '$baseUrl/promotions/$id/refine';

  // ─── Showroom Pulse / نبض المعرض ────────────────────────────
  static const String showroomPulse = '$baseUrl/showroom-pulse';
  static const String showroomPulseLever = '$baseUrl/showroom-pulse/lever';
  static const String showroomPulseTransferRequest = '$baseUrl/showroom-pulse/transfer-request';
  static const String showroomPulseDiscountSuggestion = '$baseUrl/showroom-pulse/discount-suggestion';

  // ─── Super Admin: Retail Dashboard (لوحة البيع بالتجزئة) ─────
  static const String retailDashboard = '$baseUrl/retail-dashboard';
  static String retailBranch(String warehouseCode) =>
      '$baseUrl/retail-dashboard/branches/${Uri.encodeComponent(warehouseCode)}';
  static String retailBranchItems(String warehouseCode) =>
      '$baseUrl/retail-dashboard/branches/${Uri.encodeComponent(warehouseCode)}/items';

  // ─── Super Admin: Quality Tasks management ──────────────────
  static const String qualityManage = '$baseUrl/quality-tasks/manage';
  static const String qualityManageInstances = '$baseUrl/quality-tasks/manage/instances';
  static String qualityManageTask(int id) => '$baseUrl/quality-tasks/manage/$id';
  static String qualityManageGenerate(int id) => '$baseUrl/quality-tasks/manage/$id/generate';

  // ─── Super Admin: Smart Stock Distribution ──────────────────
  static const String stockDistribution = '$baseUrl/stock-distribution';
  static const String stockDistributionStatus = '$baseUrl/stock-distribution/status';
  static const String stockDistributionRun = '$baseUrl/stock-distribution/run';

  // ─── Super Admin: Container Tracking (تتبّع الحاويات) ────────
  static const String containerTracking = '$baseUrl/container-tracking';
  static String containerTrackingDetail(int id) => '$baseUrl/container-tracking/$id';
}
