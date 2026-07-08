import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/gamification/data/gamification_repository.dart';
import 'package:exhibition_manager_app/features/gamification/data/models/gamification_models.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/widgets/badge_icons.dart';
import 'leaderboard_page.dart';

/// Achievements / إنجازاتي — points, level, streak, weekly goal, ranks, badges.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final GamificationRepository _repo = GamificationRepository();
  GamificationProfile? _profile;
  List<BadgeItem> _badges = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final me = await _repo.getMe();
    final badges = await _repo.getBadges();
    if (mounted) {
      setState(() {
        _profile = me.data;
        _badges = badges.badges;
        _loading = false;
        _error = !me.success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const Padding(
                padding: EdgeInsets.only(top: 120),
                child: SkeletonList(itemCount: 5, cardHeight: 96),
              )
            : _error || _profile == null
                ? Column(children: [
                    const SizedBox(height: 120),
                    Expanded(child: ErrorStateWidget(onRetry: _load)),
                  ])
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildHeader(isArabic),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          child: Column(
                            children: [
                              _buildStatsRow(isArabic),
                              const SizedBox(height: AppSpacing.md),
                              _buildWeeklyGoal(isArabic),
                              const SizedBox(height: AppSpacing.md),
                              _buildRanks(isArabic),
                              const SizedBox(height: AppSpacing.md),
                              _buildLeaderboardButton(),
                              const SizedBox(height: AppSpacing.lg),
                              _buildBadges(isArabic),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic) {
    final p = _profile!;
    return GradientHeader(
      title: context.tr('nav_achievements'),
      subtitle: p.levelLabel,
      child: Row(
        children: [
          ProgressRing(
            percent: p.levelProgress * 100,
            size: 96,
            stroke: 9,
            color: AppColors.accent,
            trackColor: Colors.white.withValues(alpha: 0.25),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${p.level}',
                    style: AppTypography.headlineMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(context.tr('level'),
                    style: AppTypography.labelSmall.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.pointsTotal}',
                    style: AppTypography.displayMedium.copyWith(color: Colors.white)),
                Text(context.tr('points'),
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white70)),
                if (p.pointsToNext != null) ...[
                  const SizedBox(height: 6),
                  Text('${p.pointsToNext} ${context.tr('to_next_level')}',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.accent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isArabic) {
    final p = _profile!;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.warning,
            value: '${p.streak.current}',
            label: context.tr('streak'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _statCard(
            icon: Icons.my_location_rounded,
            color: AppColors.success,
            value: '${p.accuracyAvg.toStringAsFixed(0)}%',
            label: context.tr('accuracy'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _statCard(
            icon: Icons.bolt_rounded,
            color: AppColors.primary,
            value: '${p.pointsMonth}',
            label: context.tr('this_month'),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _statCard({required IconData icon, required Color color, required String value, required String label}) {
    // Soften "nothing yet" zeros so a fresh account reads as encouraging, not empty.
    final isZero = value == '0' || value == '0%' || value == '٠' || value == '٠%';
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: isZero ? AppColors.textTertiary : color, size: 26),
          const SizedBox(height: 6),
          Text(value,
              style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isZero ? AppColors.textTertiary : AppColors.textPrimary)),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoal(bool isArabic) {
    final p = _profile!;
    final pct = p.weeklyGoalTarget > 0 ? (p.weeklyGoalCompleted / p.weeklyGoalTarget).clamp(0.0, 1.0) : 0.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.tr('weekly_goal'),
                    style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
              ),
              Text('${p.weeklyGoalCompleted}/${p.weeklyGoalTarget}',
                  style: AppTypography.labelLarge.copyWith(
                      color: pct >= 1 ? AppColors.success : AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(pct >= 1 ? AppColors.success : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRanks(bool isArabic) {
    final p = _profile!;
    return AppCard(
      child: Column(
        children: [
          _rankRow(Icons.store_mall_directory_rounded, context.tr('rank_branch'), p.branchRank, isArabic),
          const Divider(height: AppSpacing.lg),
          _rankRow(Icons.groups_rounded, context.tr('rank_in_branch'), p.withinBranchRank, isArabic),
          const Divider(height: AppSpacing.lg),
          _rankRow(Icons.public_rounded, context.tr('rank_company'), p.companyRank, isArabic),
        ],
      ),
    );
  }

  Widget _rankRow(IconData icon, String label, RankInfo rank, bool isArabic) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: AppTypography.bodyMedium)),
        Text(
          rank.position != null
              ? '${rank.position} ${context.tr('position_of')} ${rank.total}'
              : '—',
          style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLeaderboardButton() {
    return AppButton(
      label: context.tr('leaderboard'),
      icon: Icons.leaderboard_rounded,
      variant: AppButtonVariant.tonal,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardPage()),
      ),
    );
  }

  Widget _buildBadges(bool isArabic) {
    if (_badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(context.tr('badges_title'),
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, i) => _badgeTile(_badges[i], isArabic),
        ),
      ],
    );
  }

  Widget _badgeTile(BadgeItem badge, bool isArabic) {
    final earned = badge.earned;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: earned ? AppColors.goldGradient : null,
            color: earned ? null : AppColors.surfaceVariant,
            shape: BoxShape.circle,
            boxShadow: earned
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 10)]
                : null,
          ),
          child: Icon(
            earned ? badgeIcon(badge.icon) : Icons.lock_rounded,
            color: earned ? Colors.white : AppColors.textTertiary,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          badge.name(isArabic),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: earned ? AppColors.textPrimary : AppColors.textTertiary,
            fontWeight: earned ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
