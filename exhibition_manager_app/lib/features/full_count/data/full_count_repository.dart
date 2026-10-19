import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'full_count_models.dart';

/// Result of a repository call: data on success, the server's message otherwise.
class Res<T> {
  final T? data;
  final String? error;
  const Res.ok(this.data) : error = null;
  const Res.fail(this.error) : data = null;
  bool get ok => error == null;
}

/// API access for the full count and the showroom map.
class FullCountRepository {
  final ApiClient _api = ApiClient();

  Res<T> _wrap<T>(ApiResult r, T Function(dynamic data) parse) =>
      r.isSuccess ? Res.ok(parse(r.data)) : Res.fail(r.errorMessage);

  // ─── Map ─────────────────────────────────────────────────────
  Future<Res<StoreMap>> map(String wh) async =>
      _wrap(await _api.get(ApiEndpoints.storeLocations(wh)), (d) => StoreMap.fromJson(Map<String, dynamic>.from(d)));

  Future<Res<String>> addUnit(String wh, {required String kind, String? name, required int shelves}) async => _wrap(
      await _api.post(ApiEndpoints.storeLocations(wh), body: {'kind': kind, 'name': name, 'shelves': shelves}),
      (d) => '${d['unit_code']}');

  Future<Res<bool>> updateUnit(String wh, String unit, {String? name, int? shelves}) async => _wrap(
      await _api.put(ApiEndpoints.storeLocationUnit(wh, unit), body: {'name': name, 'shelves': ?shelves}), (_) => true);

  Future<Res<bool>> deleteUnit(String wh, String unit) async =>
      _wrap(await _api.delete(ApiEndpoints.storeLocationUnit(wh, unit)), (_) => true);

  Future<Res<String>> verifyLabel(String wh, String code) async =>
      _wrap(await _api.post(ApiEndpoints.storeLocationsVerify(wh), body: {'code': code}), (d) => '${d['code']}');

  Future<Res<String>> labelsLink(String wh, {String format = 'a4', String? unit}) async => _wrap(
      await _api.get(ApiEndpoints.storeLabelsLink(wh), queryParams: {'format': format, 'unit': ?unit}),
      (d) => '${d['url']}');

  // ─── Session ─────────────────────────────────────────────────
  Future<Res<FullCountSession?>> active() async => _wrap(await _api.get(ApiEndpoints.fullCountActive),
      (d) => d['data'] == null ? null : FullCountSession.fromJson(Map<String, dynamic>.from(d['data'])));

  Future<Res<FullCountSession>> start(String wh) async => _wrap(
      await _api.post(ApiEndpoints.fullCounts, body: {'warehouse_code': wh}),
      (d) => FullCountSession.fromJson(Map<String, dynamic>.from(d['data'])));

  Future<Res<FullCountBoard>> board(int id) async => _wrap(await _api.get('${ApiEndpoints.fullCount(id)}/board'),
      (d) => FullCountBoard.fromJson(Map<String, dynamic>.from(d)));

  /// claim | done | release | assign. [closePrevious] closes the counter's open unit
  /// on the way (one open unit each); [userId] is whom the manager hands it to.
  Future<Res<bool>> unitAction(int id, String unit, String action, {bool closePrevious = false, int? userId}) async =>
      _wrap(
          await _api.post('${ApiEndpoints.fullCount(id)}/units/$unit/$action', body: {
            if (closePrevious) 'close_previous': true,
            'user_id': ?userId,
          }),
          (_) => true);

  Future<Res<ScanResolution>> resolve(int id, String code) async => _wrap(
      await _api.get('${ApiEndpoints.fullCount(id)}/resolve', queryParams: {'code': code}),
      (d) => ScanResolution.fromJson(Map<String, dynamic>.from(d)));

  Future<Res<CountLine>> count(
    int id, {
    required String itemCode,
    String? locationCode,
    double? quantity,
    double? cartons,
    double? packSize,
    double? loose,
    List<ExpirySplit>? expiries,
    int round = 1,
    String? unitCode,
    bool keepOpen = false,
  }) async =>
      _wrap(
          await _api.post('${ApiEndpoints.fullCount(id)}/count', body: {
            'item_code': itemCode,
            'location_code': ?locationCode,
            'quantity': ?quantity,
            'cartons': ?cartons,
            'pack_size': ?packSize,
            'loose': ?loose,
            'expiries': ?expiries?.map((e) => e.toJson()).toList(),
            'count_round': round,
            'unit_code': ?unitCode,
            if (keepOpen) 'keep_open': true,
          }),
          (d) => CountLine.fromJson(Map<String, dynamic>.from(d['data'])));

  Future<Res<List<CountLine>>> myLines(int id, {String? location, String? item, int? round, int limit = 30}) async => _wrap(
      await _api.get('${ApiEndpoints.fullCount(id)}/my-lines',
          queryParams: {'location': ?location, 'item': ?item, 'round': ?round?.toString(), 'limit': '$limit'}),
      (d) => ((d['data'] as List?) ?? []).map((e) => CountLine.fromJson(Map<String, dynamic>.from(e))).toList());

  Future<Res<bool>> deleteLine(int id, int lineId) async =>
      _wrap(await _api.delete('${ApiEndpoints.fullCount(id)}/lines/$lineId'), (_) => true);

  /// The recounter has covered every place the item sits: their lines now count.
  Future<Res<bool>> closeRecount(int id, String itemCode) async =>
      _wrap(await _api.post('${ApiEndpoints.fullCount(id)}/recount/${Uri.encodeComponent(itemCode)}/close'), (_) => true);

  Future<Res<List<RecountItem>>> recountQueue(int id) async => _wrap(
      await _api.get('${ApiEndpoints.fullCount(id)}/recount-queue'),
      (d) => ((d['data'] as List?) ?? []).map((e) => RecountItem.fromJson(Map<String, dynamic>.from(e))).toList());

  Future<Res<List<CountProduct>>> missing(int id) async => _wrap(
      await _api.get('${ApiEndpoints.fullCount(id)}/missing'),
      (d) => ((d['data'] as List?) ?? []).map((e) => CountProduct.fromJson(Map<String, dynamic>.from(e))).toList());

  Future<Res<CountLine>> markMissing(int id, String itemCode) async => _wrap(
      await _api.post('${ApiEndpoints.fullCount(id)}/missing', body: {'item_code': itemCode}),
      (d) => CountLine.fromJson(Map<String, dynamic>.from(d['data'])));

  Future<Res<FullCountSession>> setPhase(int id, String phase) async => _wrap(
      await _api.post('${ApiEndpoints.fullCount(id)}/phase', body: {'phase': phase}),
      (d) => FullCountSession.fromJson(Map<String, dynamic>.from(d['data'])));

  Future<Res<FullCountResult>> result(int id) async => _wrap(await _api.get('${ApiEndpoints.fullCount(id)}/result'),
      (d) => FullCountResult.fromJson(Map<String, dynamic>.from(d)));

  /// [kind]: `variance` (the accountant's file) or `expiry` (every date read on the packs).
  Future<Res<String>> exportLink(int id, {String kind = 'variance'}) async => _wrap(
      await _api.get('${ApiEndpoints.fullCount(id)}/export-link', queryParams: {'kind': kind}),
      (d) => '${d['url']}');

  Future<Res<FullCountSession>> approve(int id) async => _wrap(await _api.post('${ApiEndpoints.fullCount(id)}/approve'),
      (d) => FullCountSession.fromJson(Map<String, dynamic>.from(d['data'])));

  /// Abandon the session (a rehearsal or a mistaken start); the next start opens a fresh one.
  Future<Res<FullCountSession>> cancel(int id) async => _wrap(await _api.post('${ApiEndpoints.fullCount(id)}/cancel'),
      (d) => FullCountSession.fromJson(Map<String, dynamic>.from(d['data'])));
}
