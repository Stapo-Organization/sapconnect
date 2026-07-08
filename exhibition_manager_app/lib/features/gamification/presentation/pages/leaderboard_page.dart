import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/gamification/data/gamification_repository.dart';
import 'package:exhibition_manager_app/features/gamification/data/models/gamification_models.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final GamificationRepository _repo = GamificationRepository();
  LeaderboardResponse? _data;
  bool _loading = true;
  bool _error = false;
  int _typeIndex = 0; // 0 = branches, 1 = employees

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
    final res = await _repo.getLeaderboard(type: _typeIndex == 0 ? 'branches' : 'employees');
    if (mounted) {
      setState(() {
        _data = res.data;
        _loading = false;
        _error = !res.success;
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
        appBar: MuntajatAppBar(title: context.tr('leaderboard')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: AppSegmentedControl(
                items: [
                  SegmentItem(context.tr('branches'), icon: Icons.store_mall_directory_rounded),
                  SegmentItem(context.tr('employees'), icon: Icons.groups_rounded),
                ],
                selectedIndex: _typeIndex,
                onChanged: (i) {
                  setState(() => _typeIndex = i);
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const SkeletonList(itemCount: 8, cardHeight: 64)
                  : _error || _data == null
                      ? ErrorStateWidget(onRetry: _load)
                      : _buildList(isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool isArabic) {
    final rows = _data!.rows;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(icon: Icons.leaderboard_rounded, title: context.tr('no_results')),
            ),
          for (final row in rows) _LeaderRow(row: row, isBranches: _typeIndex == 0, isArabic: isArabic),
          if (_data!.companyPosition != null) ...[
            const SizedBox(height: AppSpacing.base),
            AppCard(
              color: AppColors.primaryContainer,
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              shadow: const [],
              child: Row(
                children: [
                  Icon(Icons.public_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(context.tr('rank_company'),
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    '${_data!.companyPosition} ${context.tr('position_of')} ${_data!.companyTotal}',
                    style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry row;
  final bool isBranches;
  final bool isArabic;

  const _LeaderRow({required this.row, required this.isBranches, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final top3 = row.position <= 3;
    final medal = ['🥇', '🥈', '🥉'];
    final label = isBranches
        ? (row.name ?? row.warehouseCode ?? '—')
        : (row.name ?? context.tr('anonymous_member'));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: row.isMe ? AppColors.primaryContainer : AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: row.isMe ? AppColors.primary.withValues(alpha: 0.35) : AppColors.borderLight,
          width: row.isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: top3
                ? Text(medal[row.position - 1], style: const TextStyle(fontSize: 22), textAlign: TextAlign.center)
                : Text('${row.position}',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(label,
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (row.isMe) ...[
                  const SizedBox(width: 6),
                  StatusBadge(label: context.tr('you'), color: AppColors.primary, showDot: false),
                ],
              ],
            ),
          ),
          if (row.level != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text('L${row.level}',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accentDark, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text('${row.points}',
              style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
