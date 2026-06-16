import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/quality_admin_models.dart';

/// Data access for owner-side Quality Tasks management: list templates,
/// create them, generate instances now, and follow up across stores.
class QualityAdminRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, List<QualityTemplate> templates, String? error})> getTemplates() async {
    final r = await _api.get(ApiEndpoints.qualityManage);
    if (r.isSuccess && r.data is Map) {
      final items = (r.data['data'] as List?) ?? [];
      return (
        success: true,
        templates: items.map((e) => QualityTemplate.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        error: null,
      );
    }
    return (success: false, templates: <QualityTemplate>[], error: r.errorMessage);
  }

  Future<({bool success, List<QualityInstanceRow> instances, String? error})> getInstances({
    String? warehouse,
    String? status,
    String? date,
  }) async {
    final params = <String, String>{};
    if (warehouse != null && warehouse.isNotEmpty) params['warehouse'] = warehouse;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (date != null && date.isNotEmpty) params['date'] = date;
    final r = await _api.get(ApiEndpoints.qualityManageInstances, queryParams: params.isEmpty ? null : params);
    if (r.isSuccess && r.data is Map) {
      final items = (r.data['data'] as List?) ?? [];
      return (
        success: true,
        instances: items.map((e) => QualityInstanceRow.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        error: null,
      );
    }
    return (success: false, instances: <QualityInstanceRow>[], error: r.errorMessage);
  }

  Future<({bool success, String? error})> createTask(Map<String, dynamic> payload) async {
    final r = await _api.post(ApiEndpoints.qualityManage, body: payload);
    if (r.isSuccess) return (success: true, error: null);
    return (success: false, error: r.errorMessage);
  }

  Future<({bool success, bool active, String? error})> toggleActive(int id, bool active) async {
    final r = await _api.put(ApiEndpoints.qualityManageTask(id), body: {'is_active': active});
    if (r.isSuccess) return (success: true, active: active, error: null);
    return (success: false, active: !active, error: r.errorMessage);
  }

  Future<({bool success, int generated, String? error})> generateNow(int id) async {
    final r = await _api.post(ApiEndpoints.qualityManageGenerate(id));
    if (r.isSuccess && r.data is Map) {
      final g = r.data['generated'];
      return (success: true, generated: (g is num) ? g.toInt() : 0, error: null);
    }
    return (success: false, generated: 0, error: r.errorMessage);
  }

  Future<({bool success, List<WarehouseRef> warehouses, String? error})> getWarehouses() async {
    final r = await _api.get(ApiEndpoints.warehouses);
    if (r.isSuccess && r.data is Map) {
      final items = (r.data['data'] as List?) ?? [];
      return (
        success: true,
        warehouses: items.map((e) => WarehouseRef.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        error: null,
      );
    }
    return (success: false, warehouses: <WarehouseRef>[], error: r.errorMessage);
  }
}
