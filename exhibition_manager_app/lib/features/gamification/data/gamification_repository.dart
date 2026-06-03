import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'models/gamification_models.dart';

class GamificationRepository {
  final ApiClient _api = ApiClient();

  Future<({bool success, GamificationProfile? data, String? error})> getMe() async {
    final res = await _api.get(ApiEndpoints.gamificationMe);
    if (res.isSuccess && res.data is Map) {
      return (success: true, data: GamificationProfile.fromJson(Map<String, dynamic>.from(res.data as Map)), error: null);
    }
    return (success: false, data: null, error: res.errorMessage);
  }

  Future<({bool success, List<BadgeItem> badges, String? error})> getBadges() async {
    final res = await _api.get(ApiEndpoints.gamificationBadges);
    if (res.isSuccess && res.data is Map) {
      final list = ((res.data['badges'] as List?) ?? [])
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return (success: true, badges: list, error: null);
    }
    return (success: false, badges: <BadgeItem>[], error: res.errorMessage);
  }

  Future<({bool success, LeaderboardResponse? data, String? error})> getLeaderboard({
    String type = 'branches',
    String period = 'month',
  }) async {
    final res = await _api.get(ApiEndpoints.gamificationLeaderboard(type, period));
    if (res.isSuccess && res.data is Map) {
      return (success: true, data: LeaderboardResponse.fromJson(Map<String, dynamic>.from(res.data as Map)), error: null);
    }
    return (success: false, data: null, error: res.errorMessage);
  }
}
