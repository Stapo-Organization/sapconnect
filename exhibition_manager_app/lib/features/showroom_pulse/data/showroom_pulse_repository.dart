import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/pulse_overview.dart';

/// Data access for نبض المعرض — reads the per-branch pulse and raises the two
/// owner-facing suggestions (transfer / discount). All read-only intelligence.
class ShowroomPulseRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, PulseOverview? data, String? error})> getPulse({
    String? warehouse,
  }) async {
    final result = await _api.get(
      ApiEndpoints.showroomPulse,
      queryParams: (warehouse != null && warehouse.isNotEmpty)
          ? {'warehouse': warehouse}
          : null,
    );
    if (result.isSuccess && result.data is Map) {
      try {
        return (
          success: true,
          data: PulseOverview.fromJson(
            Map<String, dynamic>.from(result.data as Map),
          ),
          error: null,
        );
      } catch (e) {
        return (success: false, data: null, error: 'parse: $e');
      }
    }
    return (success: false, data: null, error: result.errorMessage);
  }

  Future<({bool success, String? message, String? error})> requestTransfer({
    required String itemCode,
    required String warehouseCode,
    double? quantity,
    String? note,
  }) async {
    final result = await _api.post(
      ApiEndpoints.showroomPulseTransferRequest,
      body: {
        'item_code': itemCode,
        'warehouse_code': warehouseCode,
        'quantity': ?quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return _actionResult(result);
  }

  Future<({bool success, String? message, String? error})> suggestDiscount({
    required String itemCode,
    required String warehouseCode,
    String? note,
  }) async {
    final result = await _api.post(
      ApiEndpoints.showroomPulseDiscountSuggestion,
      body: {
        'item_code': itemCode,
        'warehouse_code': warehouseCode,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return _actionResult(result);
  }

  /// Full "إظهار الكل" list for a lever (bleeding / trapped).
  Future<({bool success, List<BleedingItem> items, String? error})>
  getBleedingAll({String? warehouse}) async {
    final r = await _leverRaw('bleeding', warehouse);
    if (!r.success)
      return (success: false, items: <BleedingItem>[], error: r.error);
    return (
      success: true,
      items: r.items.map(BleedingItem.fromJson).toList(),
      error: null,
    );
  }

  Future<({bool success, List<TrappedItem> items, String? error})>
  getTrappedAll({String? warehouse}) async {
    final r = await _leverRaw('trapped', warehouse);
    if (!r.success)
      return (success: false, items: <TrappedItem>[], error: r.error);
    return (
      success: true,
      items: r.items.map(TrappedItem.fromJson).toList(),
      error: null,
    );
  }

  Future<({bool success, List<BasketPair> items, String? error})> getBasketAll({
    String? warehouse,
  }) async {
    final r = await _leverRaw('basket', warehouse);
    if (!r.success)
      return (success: false, items: <BasketPair>[], error: r.error);
    return (
      success: true,
      items: r.items.map(BasketPair.fromJson).toList(),
      error: null,
    );
  }

  Future<({bool success, List<Map<String, dynamic>> items, String? error})>
  _leverRaw(String type, String? warehouse) async {
    final params = <String, String>{
      'type': type,
      if (warehouse != null && warehouse.isNotEmpty) 'warehouse': warehouse,
    };
    final result = await _api.get(
      ApiEndpoints.showroomPulseLever,
      queryParams: params,
    );
    if (result.isSuccess && result.data is Map) {
      final raw = ((result.data['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return (success: true, items: raw, error: null);
    }
    return (
      success: false,
      items: <Map<String, dynamic>>[],
      error: result.errorMessage,
    );
  }

  ({bool success, String? message, String? error}) _actionResult(
    ApiResult result,
  ) {
    if (result.isSuccess) {
      final msg = result.data is Map
          ? (result.data['message'] as String?)
          : null;
      return (success: true, message: msg, error: null);
    }
    return (success: false, message: null, error: result.errorMessage);
  }
}
