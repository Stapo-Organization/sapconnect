import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/zooboxi_order.dart';

/// Elapsed-time label from minutes ("منذ ٤٥ د" / "منذ ٢ س").
String elapsedLabel(BuildContext context, int minutes) {
  if (minutes < 60) {
    return context.tr('minutes_ago').replaceAll('{x}', '$minutes');
  }
  return context.tr('hours_ago').replaceAll('{x}', '${minutes ~/ 60}');
}

class ZooboxiOrderCard extends StatelessWidget {
  final ZooboxiOrder order;
  final VoidCallback onTap;

  /// Live minutes-waiting value (recomputed by the page timer). When null,
  /// falls back to the server-provided value.
  final int? minutesOverride;

  const ZooboxiOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.minutesOverride,
  });

  @override
  Widget build(BuildContext context) {
    final done = order.isDone;
    final accent = done ? AppColors.success : AppDomain.zooboxi.accent; // green vs urgency crimson
    final minutes = minutesOverride ?? order.minutesSinceCreated;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: accent.withValues(alpha: 0.18),
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
              child: Icon(done ? Icons.check_circle_rounded : Icons.bolt_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${context.tr('order_no')} ${order.reference}',
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!done) ...[
                        const SizedBox(width: 6),
                        // Live "waiting for X" counter.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 11, color: accent),
                              const SizedBox(width: 3),
                              Text(
                                elapsedLabel(context, minutes),
                                style: AppTypography.labelSmall.copyWith(
                                    color: accent, fontWeight: FontWeight.w700, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (order.customer.name != null && order.customer.name!.isNotEmpty) order.customer.name!,
                      '${order.totalItems.toInt()} ${context.tr('items')}',
                    ].join(' • '),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (done)
              StatusBadge(
                label: order.deliveryStatusLabel.isNotEmpty ? order.deliveryStatusLabel : context.tr('status_done'),
                color: AppColors.success,
                icon: Icons.check_rounded,
              )
            else if (order.isPreparing)
              StatusBadge(
                label: context.tr('status_preparing'),
                color: AppColors.warning,
                icon: Icons.timelapse_rounded,
              )
            else
              Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
