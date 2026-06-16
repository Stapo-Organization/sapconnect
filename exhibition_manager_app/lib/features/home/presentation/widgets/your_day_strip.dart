import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/home/data/models/home_overview.dart';

/// Contextual "your day" card — what the user closed out today + their streak,
/// with a weekly-goal [ProgressRing]. Pure motivation; carries no actions.
class YourDayStrip extends StatelessWidget {
  final YourDay day;
  final HomeProgress progress;

  const YourDayStrip({super.key, required this.day, required this.progress});

  /// Nothing closed out yet — early in the day. Show an encouraging start
  /// line instead of a row of demotivating zeros.
  bool get _nothingYet =>
      day.ordersFulfilledToday == 0 && day.tasksDoneToday == 0 && day.streak == 0;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          if (progress.hasGoal) ...[
            ProgressRing(
              percent: progress.percent.toDouble(),
              size: 64,
              stroke: 7,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${progress.current}/${progress.target}',
                    style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.base),
          ],
          Expanded(
            child: _nothingYet ? _startState(context) : _summaryState(context),
          ),
        ],
      ),
    );
  }

  Widget _startState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('your_day_start'),
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('your_day_start_hint'),
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _summaryState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('your_day'),
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _metric(
              icon: Icons.bolt_rounded,
              value: '${day.ordersFulfilledToday}',
              label: context.tr('orders_fulfilled_today'),
              color: AppDomain.zooboxi.accent,
            ),
            _divider(),
            _metric(
              icon: Icons.task_alt_rounded,
              value: '${day.tasksDoneToday}',
              label: context.tr('tasks_done_today'),
              color: AppDomain.counting.accent,
            ),
            if (day.streak > 0) ...[
              _divider(),
              _metric(
                icon: Icons.local_fire_department_rounded,
                value: '${day.streak}',
                label: context.tr('streak'),
                color: AppColors.warning,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        color: AppColors.borderLight,
      );

  Widget _metric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                value,
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
