import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/retail_models.dart';

/// One ranked wholesale customer: rank medal · name · net-sales hero with a
/// share-of-leader bar · profit/margin badge · invoices chip · returns flag.
/// Mirrors [LeaderboardRow]'s anatomy so the two leaderboards read as one
/// system — minus the pulse ring (there is no showroom pulse for a customer).
class WholesaleCustomerRow extends StatelessWidget {
  final WholesaleCustomer customer;
  final int rank; // 1-based position in the sorted list
  final double maxNet; // leader's net, for the relative bar

  const WholesaleCustomerRow({
    super.key,
    required this.customer,
    required this.rank,
    required this.maxNet,
  });

  static const _gold = Color(0xFFF4BE2C);
  static const _silver = Color(0xFFADB9C7);
  static const _bronze = Color(0xFFCD8246);

  Color get _rankColor => switch (rank) {
        1 => _gold,
        2 => _silver,
        3 => _bronze,
        _ => AppColors.accentDark,
      };

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentDark;
    final share = maxNet > 0 ? (customer.net / maxNet).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
                      child: Text(customer.name,
                          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(sarAmount(customer.net),
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
                      valueColor: AlwaysStoppedAnimation(AppColors.accent.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (customer.marginPct != null) Flexible(child: _profitBadge(context)),
                    if (customer.marginPct != null) const SizedBox(width: AppSpacing.sm),
                    _invoicesChip(context),
                    const Spacer(),
                    if (customer.returns > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _returnsChip(context),
                    ],
                  ],
                ),
              ],
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
          Flexible(
            child: Text(compactNum(customer.profit),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 5),
          Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('${customer.marginPct!.toStringAsFixed(0)}٪',
              style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _invoicesChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.borderFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text('${intGrouped(customer.invoices)} ${context.tr('rd_invoices_short')}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _returnsChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: AppRadius.borderFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.u_turn_left_rounded, size: 12, color: AppColors.error),
          const SizedBox(width: 3),
          Text(compactNum(customer.returns),
              style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
