/// Muntajat Exhibition Manager — API Endpoints
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://sapapi.muntajat.sa/api';

  // ─── Auth ──────────────────────────────────────────────────
  static const String login = '$baseUrl/login';
  static const String logout = '$baseUrl/logout';
  static const String profile = '$baseUrl/profile';

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

  // ─── Warehouses ────────────────────────────────────────────
  // ─── Gamification ──────────────────────────────────────────
  static const String gamificationMe = '$baseUrl/gamification/me';
  static const String gamificationBadges = '$baseUrl/gamification/badges';
  static String gamificationLeaderboard(String type, String period) =>
      '$baseUrl/gamification/leaderboard?type=$type&period=$period';

  static const String warehouses = '$baseUrl/warehouses';

  // ─── Dashboard Stats ──────────────────────────────────────
  static const String dashboardStats = '$baseUrl/dashboard-stats';
}
