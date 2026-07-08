import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/progress_ring.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/retail_models.dart';

/// One ranked branch in the leaderboard: rank medal · name/city · net-sales hero
/// with a share-of-leader bar · pulse ring · a small bleeding flag.
class LeaderboardRow extends StatelessWidget {
  final BranchCard branch;
  final int rank; // 1-based position in the sorted list
  final double maxNet; // leader's net, for the relative bar
  final VoidCallback onTap;

  const LeaderboardRow({
    super.key,
    required this.branch,
    required this.rank,
    required this.maxNet,
    required this.onTap,
  });

  static const _gold = Color(0xFFF4BE2C);
  static const _silver = Color(0xFFADB9C7);
  static const _bronze = Color(0xFFCD8246);

  Color get _rankColor => switch (rank) {
        1 => _gold,
        2 => _silver,
        3 => _bronze,
        _ => AppDomain.admin.accent,
      };

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.admin.accent;
    final share = maxNet > 0 ? (branch.revenue.net / maxNet).clamp(0.0, 1.0) : 0.0;
    final parts = branch.name.split('·');
    final name = parts.first.trim();
    final city = parts.length > 1 ? parts[1].trim() : null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          _rankMedal(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (city != null) ...[
                            const SizedBox(width: 6),
                            Text(city, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                          ],
                        ],
                      ),
                    ),
                    Text(sarAmount(branch.revenue.net),
                        style: AppTypography.titleSmall.copyWith(color: accent, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (branch.profit.marginPct != null) Flexible(child: _profitBadge(context)),
                    const Spacer(),
                    if (branch.bleedingMonthlySar > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _bleedChip(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ProgressRing(
            percent: branch.score ?? 0,
            size: 46,
            stroke: 5,
            center: Text(
              branch.score != null ? branch.score!.toStringAsFixed(0) : '—',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankMedal() {
    final top3 = rank <= 3;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: top3 ? _rankColor : _rankColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: AppTypography.labelMedium.copyWith(
          color: top3 ? Colors.white : _rankColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _profitBadge(BuildContext context) {
    final p = branch.profit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: AppRadius.borderFull,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 13, color: AppColors.success),
          const SizedBox(width: 4),
          Text(context.tr('rd_profit_short'),
              style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(compactNum(p.profit),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 5),
          Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('${p.marginPct!.toStringAsFixed(0)}٪',
              style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _bleedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: AppRadius.borderFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down_rounded, size: 12, color: AppColors.error),
          const SizedBox(width: 3),
          Text(compactNum(branch.bleedingMonthlySar),
              style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
