// Gamification models (GET /gamification/me, /badges, /leaderboard).

class StreakInfo {
  final int current;
  final int longest;
  const StreakInfo({this.current = 0, this.longest = 0});
  factory StreakInfo.fromJson(Map<String, dynamic> j) =>
      StreakInfo(current: j['current'] ?? 0, longest: j['longest'] ?? 0);
}

class RankInfo {
  final int? position;
  final int total;
  final bool named;
  const RankInfo({this.position, this.total = 0, this.named = false});
  factory RankInfo.fromJson(Map<String, dynamic>? j) => RankInfo(
        position: j?['position'],
        total: j?['total'] ?? 0,
        named: j?['named'] == true,
      );
}

class GamificationProfile {
  final int pointsTotal;
  final int pointsMonth;
  final int level;
  final String levelLabel;
  final int pointsIntoLevel;
  final int? pointsToNext;
  final int? nextLevelSpan;
  final StreakInfo streak;
  final double accuracyAvg;
  final int fullCounts;
  final int cycleCounts;
  final int weeklyGoalTarget;
  final int weeklyGoalCompleted;
  final RankInfo branchRank;
  final RankInfo withinBranchRank;
  final RankInfo companyRank;
  final List<BadgeItem> recentBadges;

  GamificationProfile({
    required this.pointsTotal,
    required this.pointsMonth,
    required this.level,
    required this.levelLabel,
    required this.pointsIntoLevel,
    this.pointsToNext,
    this.nextLevelSpan,
    required this.streak,
    required this.accuracyAvg,
    required this.fullCounts,
    required this.cycleCounts,
    required this.weeklyGoalTarget,
    required this.weeklyGoalCompleted,
    required this.branchRank,
    required this.withinBranchRank,
    required this.companyRank,
    required this.recentBadges,
  });

  /// Progress (0..1) toward the next level.
  double get levelProgress {
    if (nextLevelSpan == null || nextLevelSpan == 0) return 1;
    return (pointsIntoLevel / nextLevelSpan!).clamp(0, 1);
  }

  factory GamificationProfile.fromJson(Map<String, dynamic> j) {
    final rank = (j['rank'] as Map?) ?? {};
    final counts = (j['counts'] as Map?) ?? {};
    final goal = (j['weekly_goal'] as Map?) ?? {};
    return GamificationProfile(
      pointsTotal: j['points_total'] ?? 0,
      pointsMonth: j['points_month'] ?? 0,
      level: j['level'] ?? 1,
      levelLabel: j['level_label'] ?? '',
      pointsIntoLevel: j['points_into_level'] ?? 0,
      pointsToNext: j['points_to_next'],
      nextLevelSpan: j['next_level_span'],
      streak: StreakInfo.fromJson(Map<String, dynamic>.from((j['streak'] as Map?) ?? {})),
      accuracyAvg: (j['accuracy_avg'] ?? 0).toDouble(),
      fullCounts: counts['full'] ?? 0,
      cycleCounts: counts['cycle'] ?? 0,
      weeklyGoalTarget: goal['target'] ?? 1,
      weeklyGoalCompleted: goal['completed'] ?? 0,
      branchRank: RankInfo.fromJson(rank['branch'] is Map ? Map<String, dynamic>.from(rank['branch']) : null),
      withinBranchRank: RankInfo.fromJson(rank['within_branch'] is Map ? Map<String, dynamic>.from(rank['within_branch']) : null),
      companyRank: RankInfo.fromJson(rank['company'] is Map ? Map<String, dynamic>.from(rank['company']) : null),
      recentBadges: ((j['recent_badges'] as List?) ?? [])
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class BadgeItem {
  final String code;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String descAr;
  final String descEn;
  final bool earned;

  BadgeItem({
    required this.code,
    this.nameAr = '',
    this.nameEn = '',
    this.icon = 'star',
    this.descAr = '',
    this.descEn = '',
    this.earned = true,
  });

  factory BadgeItem.fromJson(Map<String, dynamic> j) => BadgeItem(
        code: j['code'] ?? '',
        nameAr: j['name_ar'] ?? '',
        nameEn: j['name_en'] ?? '',
        icon: j['icon'] ?? 'star',
        descAr: j['desc_ar'] ?? '',
        descEn: j['desc_en'] ?? '',
        earned: j['earned'] ?? true,
      );

  String name(bool ar) => ar ? (nameAr.isNotEmpty ? nameAr : nameEn) : (nameEn.isNotEmpty ? nameEn : nameAr);
  String desc(bool ar) => ar ? descAr : descEn;
}

class LeaderboardEntry {
  final int position;
  final int? userId;
  final String? name;
  final String? warehouseCode;
  final int points;
  final int? level;
  final bool isMe;

  LeaderboardEntry({
    required this.position,
    this.userId,
    this.name,
    this.warehouseCode,
    this.points = 0,
    this.level,
    this.isMe = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        position: j['position'] ?? 0,
        userId: j['user_id'],
        name: j['name'],
        warehouseCode: j['warehouse_code'],
        points: j['points'] ?? 0,
        level: j['level'],
        isMe: j['is_me'] == true,
      );
}

class LeaderboardResponse {
  final String type;
  final String? scope;
  final List<LeaderboardEntry> rows;
  final int? companyPosition;
  final int? companyTotal;

  LeaderboardResponse({
    required this.type,
    this.scope,
    required this.rows,
    this.companyPosition,
    this.companyTotal,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> j) {
    final company = (j['company'] as Map?);
    return LeaderboardResponse(
      type: j['type'] ?? 'branches',
      scope: j['scope'],
      rows: ((j['rows'] as List?) ?? [])
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      companyPosition: company?['position'],
      companyTotal: company?['total'],
    );
  }
}
