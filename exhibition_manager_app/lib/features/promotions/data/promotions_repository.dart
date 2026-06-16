import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/campaign.dart';

/// Promotions / ad-campaigns repository (owner only) — record-return style,
/// mirroring ZooboxiOrdersRepository.
class PromotionsRepository {
  final ApiClient _api = ApiClient();

  /// Home summary — pending count + a few suggested previews.
  Future<({bool success, int pendingCount, int activeCount, List<Campaign> campaigns, String? error})> getSummary() async {
    final result = await _api.get(ApiEndpoints.promotionsSummary);
    if (result.isSuccess) {
      try {
        final List items = result.data['campaigns'] ?? [];
        return (
          success: true,
          pendingCount: (result.data['pending_count'] ?? 0) as int,
          activeCount: (result.data['active_count'] ?? 0) as int,
          campaigns: items.map((e) => Campaign.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          error: null,
        );
      } catch (e) {
        return (success: false, pendingCount: 0, activeCount: 0, campaigns: <Campaign>[], error: 'parse: $e');
      }
    }
    return (success: false, pendingCount: 0, activeCount: 0, campaigns: <Campaign>[], error: result.errorMessage);
  }

  /// List campaigns by [status]: suggested | scheduled | active | ended.
  Future<({bool success, List<Campaign> campaigns, String? error})> getCampaigns({String status = 'suggested'}) async {
    final result = await _api.get(ApiEndpoints.promotions, queryParams: {'status': status});
    if (result.isSuccess) {
      try {
        final List items = result.data['data'] ?? [];
        return (success: true, campaigns: items.map((e) => Campaign.fromJson(Map<String, dynamic>.from(e as Map))).toList(), error: null);
      } catch (e) {
        return (success: false, campaigns: <Campaign>[], error: 'parse: $e');
      }
    }
    return (success: false, campaigns: <Campaign>[], error: result.errorMessage);
  }

  Future<({bool success, Campaign? campaign, String? error})> getCampaign(int id) async {
    final result = await _api.get(ApiEndpoints.promotion(id));
    if (result.isSuccess) {
      final data = result.data['data'] ?? result.data;
      return (success: true, campaign: Campaign.fromJson(Map<String, dynamic>.from(data as Map)), error: null);
    }
    return (success: false, campaign: null, error: result.errorMessage);
  }

  /// Available ad slots (placements) for the picker.
  Future<({bool success, List<AdPlacement> placements, String? error})> getPlacements() async {
    final result = await _api.get(ApiEndpoints.promotionsPlacements);
    if (result.isSuccess) {
      try {
        final List items = result.data['data'] ?? [];
        return (success: true, placements: items.map((e) => AdPlacement.fromJson(Map<String, dynamic>.from(e as Map))).toList(), error: null);
      } catch (e) {
        return (success: false, placements: <AdPlacement>[], error: 'parse: $e');
      }
    }
    return (success: false, placements: <AdPlacement>[], error: result.errorMessage);
  }

  /// Approve the concept + pick a placement (+ optional copy). Triggers generation
  /// of the single placement creative (preview — not live until published).
  Future<({bool success, Campaign? campaign, String? error})> approve(
    int id, {
    required String placement,
    String? designIdentity,
    String? headline,
    String? subheadline,
    String? cta,
  }) async {
    final body = <String, dynamic>{'placement': placement};
    if (designIdentity != null) body['design_identity'] = designIdentity;
    if (headline != null) body['headline'] = headline;
    if (subheadline != null) body['subheadline'] = subheadline;
    if (cta != null) body['cta'] = cta;
    final result = await _api.post(ApiEndpoints.promotionApprove(id), body: body);
    if (result.isSuccess) {
      final data = result.data['data'];
      return (success: true, campaign: data != null ? Campaign.fromJson(Map<String, dynamic>.from(data as Map)) : null, error: null);
    }
    return (success: false, campaign: null, error: result.errorMessage);
  }

  /// Publish the previewed creative live into its placement.
  Future<({bool success, bool published, String? error})> publish(int id, {String? variant}) async {
    final result = await _api.post(ApiEndpoints.promotionPublish(id), body: variant != null ? {'variant': variant} : null);
    return (success: result.isSuccess, published: result.data['published'] == true, error: result.isSuccess ? null : result.errorMessage);
  }

  Future<({bool success, String? error})> reject(int id, {String? reason, String? category}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    if (category != null && category.isNotEmpty) body['category'] = category;
    final result = await _api.post(ApiEndpoints.promotionReject(id), body: body.isEmpty ? null : body);
    return (success: result.isSuccess, error: result.isSuccess ? null : result.errorMessage);
  }

  Future<({bool success, String? error})> regenerate(int id) async {
    final result = await _api.post(ApiEndpoints.promotionRegenerate(id));
    return (success: result.isSuccess, error: result.isSuccess ? null : result.errorMessage);
  }

  /// Re-render the creative to the owner's free-text note (AI edit).
  Future<({bool success, String? error})> refine(int id, String note) async {
    final result = await _api.post(ApiEndpoints.promotionRefine(id), body: {'note': note});
    return (success: result.isSuccess, error: result.isSuccess ? null : result.errorMessage);
  }
}
