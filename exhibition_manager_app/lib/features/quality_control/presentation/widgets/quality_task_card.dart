import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/quality_control/data/models/quality_task_models.dart';

class QualityTaskCard extends StatelessWidget {
  final QualityTaskInstance task;
  final VoidCallback onTap;
  const QualityTaskCard({super.key, required this.task, required this.onTap});

  IconData get _proofIcon {
    switch (task.requirements.proofType) {
      case 'acknowledge':
        return Icons.task_alt_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      default:
        return Icons.photo_camera_rounded;
    }
  }

  Color get _accent {
    if (task.isSubmitted) return AppColors.success;
    if (task.isOverdue) return AppColors.error;
    switch (task.priority) {
      case 'high':
        return AppColors.error;
      case 'low':
        return AppColors.textTertiary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final slot = task.slotLabel(isArabic);
    final accent = _accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(_proofIcon, color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(task.title,
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (slot.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(slot,
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.accentDark, fontWeight: FontWeight.w700, fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(task.warehouseName ?? task.warehouseCode,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (task.isSubmitted)
              StatusBadge(label: context.tr('status_submitted'), color: AppColors.success, icon: Icons.check_rounded)
            else if (task.isOverdue)
              StatusBadge(label: context.tr('overdue_badge'), color: AppColors.error, icon: Icons.warning_amber_rounded)
            else
              Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
