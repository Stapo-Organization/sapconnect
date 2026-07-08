import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';

import '../../data/models/container_models.dart';
import 'container_style.dart';

/// One shipment row: state chip · ocean-lane (origin → destination) · carrier ·
/// a voyage progress bar tinted by state · ETA and the time-to-arrival.
class ContainerCardTile extends StatelessWidget {
  final ContainerCard c;
  final VoidCallback onTap;
  const ContainerCardTile({super.key, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = containerStateColor(c.stateColor);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statePill(color),
              const Spacer(),
              Text(c.remainingLabel,
                  style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _lane(),
          const SizedBox(height: AppSpacing.sm + 2),
          _progress(color),
          const SizedBox(height: AppSpacing.sm),
          _footer(context),
        ],
      ),
    );
  }

  Widget _statePill(Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(c.stateLabel,
                style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  // Route always reads left→right (origin → destination) regardless of locale.
  Widget _lane() => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _endpoint(c.originFlag, c.originShort),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 2, color: AppColors.borderLight)),
                    Icon(Icons.directions_boat_rounded, size: 16, color: AppColors.textTertiary),
                    Expanded(child: Container(height: 2, color: AppColors.borderLight)),
                  ],
                ),
              ),
            ),
            _endpoint(c.destinationFlag, c.destinationShort),
          ],
        ),
      );

  Widget _endpoint(String flag, String place) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      );

  Widget _progress(Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (c.progressPercent / 100).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      );

  Widget _footer(BuildContext context) => Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(c.carrier ?? c.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.event_available_outlined, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(shortDate(c.eta),
              style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          if (c.etaChangeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: AppRadius.borderFull),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update_rounded, size: 12, color: AppColors.error),
                  const SizedBox(width: 3),
                  Text('${c.etaChangeCount}',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      );
}
