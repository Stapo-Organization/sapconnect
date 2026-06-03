import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/quality_task_models.dart';

/// Quality Control repository — mirrors the CountingRepository record style.
class QualityControlRepository {
  final ApiClient _api = ApiClient();

  /// List instances for the user's warehouses.
  Future<({bool success, List<QualityTaskInstance> tasks, String? error})> getTasks({
    String? status,
    String? date,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (date != null) params['date'] = date;

    final result = await _api.get(ApiEndpoints.qualityTasks, queryParams: params.isEmpty ? null : params);
    if (result.isSuccess) {
      try {
        final List items = result.data['data'] ?? [];
        return (success: true, tasks: items.map((e) => QualityTaskInstance.fromJson(e)).toList(), error: null);
      } catch (e) {
        return (success: false, tasks: <QualityTaskInstance>[], error: 'parse: $e');
      }
    }
    return (success: false, tasks: <QualityTaskInstance>[], error: result.errorMessage);
  }

  /// Home summary — due/overdue counts + the next due tasks.
  Future<({bool success, int dueCount, int overdueCount, List<QualityTaskInstance> due, String? error})> getSummary() async {
    final result = await _api.get(ApiEndpoints.qualityTasksSummary);
    if (result.isSuccess) {
      try {
        final List due = result.data['due'] ?? [];
        return (
          success: true,
          dueCount: (result.data['due_count'] ?? 0) as int,
          overdueCount: (result.data['overdue_count'] ?? 0) as int,
          due: due.map((e) => QualityTaskInstance.fromJson(e)).toList(),
          error: null,
        );
      } catch (e) {
        return (success: false, dueCount: 0, overdueCount: 0, due: <QualityTaskInstance>[], error: 'parse: $e');
      }
    }
    return (success: false, dueCount: 0, overdueCount: 0, due: <QualityTaskInstance>[], error: result.errorMessage);
  }

  Future<({bool success, QualityTaskInstance? task, String? error})> getTask(int id) async {
    final result = await _api.get(ApiEndpoints.qualityTask(id));
    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (success: true, task: QualityTaskInstance.fromJson(data), error: null);
    }
    return (success: false, task: null, error: result.errorMessage);
  }

  /// Upload one or more photos; optionally tied to a checklist item.
  Future<({bool success, List<QualityTaskPhoto> photos, String? error})> uploadPhotos(
    int id,
    List<String> filePaths, {
    String? checklistItemKey,
  }) async {
    final result = await _api.postMultipart(
      ApiEndpoints.qualityTaskPhotos(id),
      fields: checklistItemKey != null ? {'checklist_item_key': checklistItemKey} : null,
      filePaths: filePaths,
      fileField: 'photos[]',
    );
    if (result.isSuccess) {
      final List photos = result.data['photos'] ?? [];
      return (success: true, photos: photos.map((e) => QualityTaskPhoto.fromJson(e)).toList(), error: null);
    }
    return (success: false, photos: <QualityTaskPhoto>[], error: result.errorMessage);
  }

  Future<({bool success, String? error})> deletePhoto(int id, int photoId) async {
    final result = await _api.delete(ApiEndpoints.qualityTaskPhoto(id, photoId));
    return (success: result.isSuccess, error: result.errorMessage);
  }

  /// Submit the task. Returns the gamification block for the celebration.
  Future<({bool success, Map<String, dynamic>? gamification, QualityTaskInstance? task, String? error})> submit(
    int id, {
    String? comment,
    Map<String, dynamic>? checklistResults,
  }) async {
    final body = <String, dynamic>{};
    if (comment != null && comment.isNotEmpty) body['comment'] = comment;
    if (checklistResults != null) body['checklist_results'] = checklistResults;

    final result = await _api.post(ApiEndpoints.qualityTaskSubmit(id), body: body);
    if (result.isSuccess) {
      final data = result.data['data'];
      return (
        success: true,
        gamification: result.data['gamification'] is Map ? Map<String, dynamic>.from(result.data['gamification']) : null,
        task: data != null ? QualityTaskInstance.fromJson(data) : null,
        error: null,
      );
    }
    return (success: false, gamification: null, task: null, error: result.errorMessage);
  }
}
