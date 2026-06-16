import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/counting_session.dart';
import 'models/cycle_target.dart';

/// Inventory Counting repository
class CountingRepository {
  final ApiClient _api = ApiClient();

  /// List counting sessions
  Future<({bool success, List<CountingSession> sessions, String? error})>
  getSessions({
    String? status,
    String? warehouseCode,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null) params['status'] = status;
    if (warehouseCode != null) params['warehouse_code'] = warehouseCode;

    final result = await _api.get(
      ApiEndpoints.inventoryCountings,
      queryParams: params,
    );

    if (result.isSuccess) {
      final List items = result.data['data'] ?? [];
      final sessions = items.map((e) => CountingSession.fromJson(e)).toList();
      return (success: true, sessions: sessions, error: null);
    }

    return (
      success: false,
      sessions: <CountingSession>[],
      error: result.errorMessage,
    );
  }

  /// Create new counting session
  Future<({bool success, CountingSession? session, String? error})>
  createSession({required String warehouseCode, String? notes}) async {
    final result = await _api.post(
      ApiEndpoints.inventoryCountings,
      body: {'warehouse_code': warehouseCode, 'notes': ?notes},
    );

    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (
        success: true,
        session: CountingSession.fromJson(data),
        error: null,
      );
    }

    return (success: false, session: null, error: result.errorMessage);
  }

  /// Get single counting session details
  Future<({bool success, CountingSession? session, String? error})> getSession(
    int id,
  ) async {
    final result = await _api.get(ApiEndpoints.inventoryCounting(id));

    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (
        success: true,
        session: CountingSession.fromJson(data),
        error: null,
      );
    }

    return (success: false, session: null, error: result.errorMessage);
  }

  /// Scan barcode within a counting session
  Future<({bool success, ScannedProduct? product, String? error})> scanBarcode(
    int sessionId,
    String barcode,
  ) async {
    final result = await _api.post(
      ApiEndpoints.countingScan(sessionId),
      body: {'barcode': barcode},
    );

    if (result.isSuccess) {
      return (
        success: true,
        product: ScannedProduct.fromJson(result.data),
        error: null,
      );
    }

    return (success: false, product: null, error: result.errorMessage);
  }

  /// Add or update a counting line
  Future<({bool success, CountingLine? line, String? error})> addLine(
    int sessionId,
    String itemCode,
    double quantity,
  ) async {
    final result = await _api.post(
      ApiEndpoints.countingLines(sessionId),
      body: {'item_code': itemCode, 'counted_quantity': quantity},
    );

    if (result.isSuccess) {
      final lineData = result.data['line'];
      return (
        success: true,
        line: lineData != null ? CountingLine.fromJson(lineData) : null,
        error: null,
      );
    }

    return (success: false, line: null, error: result.errorMessage);
  }

  /// Update a counting line quantity
  Future<({bool success, String? error})> updateLine(
    int sessionId,
    int lineId,
    double quantity,
  ) async {
    final result = await _api.put(
      ApiEndpoints.countingLine(sessionId, lineId),
      body: {'counted_quantity': quantity},
    );

    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Delete a counting line
  Future<({bool success, String? error})> deleteLine(
    int sessionId,
    int lineId,
  ) async {
    final result = await _api.delete(
      ApiEndpoints.countingLine(sessionId, lineId),
    );
    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Complete counting session — returns variance summary + gamification result
  Future<
    ({
      bool success,
      Map<String, dynamic>? varianceSummary,
      Map<String, dynamic>? gamification,
      String? error,
    })
  >
  completeSession(int id) async {
    final result = await _api.post(ApiEndpoints.countingComplete(id));
    if (result.isSuccess) {
      return (
        success: true,
        varianceSummary:
            result.data['variance_summary'] as Map<String, dynamic>?,
        gamification: result.data['gamification'] is Map
            ? Map<String, dynamic>.from(result.data['gamification'] as Map)
            : null,
        error: null,
      );
    }
    return (
      success: false,
      varianceSummary: null,
      gamification: null,
      error: result.errorMessage,
    );
  }

  /// Cancel counting session
  Future<({bool success, String? error})> cancelSession(int id) async {
    final result = await _api.post(ApiEndpoints.countingCancel(id));
    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Lookup product by barcode (standalone)
  Future<({bool success, Map<String, dynamic>? product, String? error})>
  lookupBarcode(String barcode) async {
    final result = await _api.get(ApiEndpoints.productByBarcode(barcode));

    if (result.isSuccess) {
      return (
        success: true,
        product: result.data['product'] as Map<String, dynamic>?,
        error: null,
      );
    }

    return (success: false, product: null, error: result.errorMessage);
  }

  // ─── Cycle Counting ─────────────────────────────────────────

  /// Get variance report for a completed counting session
  Future<({bool success, Map<String, dynamic>? report, String? error})>
  getVarianceReport(int sessionId) async {
    final result = await _api.get(
      ApiEndpoints.countingVarianceReport(sessionId),
    );
    if (result.isSuccess) {
      return (
        success: true,
        report: result.data as Map<String, dynamic>?,
        error: null,
      );
    }
    return (success: false, report: null, error: result.errorMessage);
  }

  /// Get counting schedule (overdue + upcoming)
  Future<({bool success, Map<String, dynamic>? data, String? error})>
  getSchedule() async {
    final result = await _api.get(ApiEndpoints.countingSchedule);
    if (result.isSuccess) {
      return (
        success: true,
        data: result.data as Map<String, dynamic>?,
        error: null,
      );
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  /// Add investigation note to a line
  Future<({bool success, String? error})> investigate(
    int sessionId,
    int lineId,
    String note,
  ) async {
    final result = await _api.post(
      ApiEndpoints.countingInvestigate(sessionId, lineId),
      body: {'note': note},
    );
    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Get ABC summary for a warehouse
  Future<({bool success, Map<String, dynamic>? data, String? error})>
  getAbcSummary(String warehouseCode) async {
    final result = await _api.get(
      ApiEndpoints.countingAbcSummary(warehouseCode),
    );
    if (result.isSuccess) {
      return (
        success: true,
        data: result.data as Map<String, dynamic>?,
        error: null,
      );
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  /// Get cycle counting progress for a warehouse
  Future<({bool success, Map<String, dynamic>? data, String? error})>
  getCycleProgress(String warehouseCode) async {
    final result = await _api.get(
      ApiEndpoints.countingCycleProgress(warehouseCode),
    );
    if (result.isSuccess) {
      return (
        success: true,
        data: result.data as Map<String, dynamic>?,
        error: null,
      );
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  /// Get the target items + progress for a cycle session (guided experience)
  Future<({bool success, CycleTargetsResponse? data, String? error})>
  getCycleTargets(int sessionId) async {
    final result = await _api.get(ApiEndpoints.countingTargets(sessionId));
    if (result.isSuccess && result.data is Map) {
      return (
        success: true,
        data: CycleTargetsResponse.fromJson(
          Map<String, dynamic>.from(result.data as Map),
        ),
        error: null,
      );
    }
    return (success: false, data: null, error: result.errorMessage);
  }
}
