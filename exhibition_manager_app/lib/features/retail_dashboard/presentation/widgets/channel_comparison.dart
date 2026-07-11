import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/app_card.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

import '../../data/models/retail_models.dart';
import '../channel_tokens.dart';

/// المعارض مقابل الجملة — the total view's centerpiece: two tappable channel
/// cards (indigo showrooms / gold wholesale) and an animated stacked bar
/// showing each channel's share of net sales. Tapping a card drills into
/// that channel's dedicated view.
class ChannelComparison extends StatelessWidget {
  final ChannelSplit channels;
  final void Function(String channel) onOpenChannel;

  const ChannelComparison({
    super.key,
    required this.channels,
    required this.onOpenChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _channelCard(
                context,
                channel: SalesChannel.retail,
                totals: channels.retail,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _channelCard(
                context,
                channel: SalesChannel.wholesale,
                totals: channels.wholesale,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _shareBar(context),
      ],
    );
  }

  Widget _channelCard(BuildContext context, {required String channel, required ChannelTotals totals}) {
    final color = SalesChannel.color(channel);
    return AppCard(
      onTap: () => onOpenChannel(channel),
      padding: const EdgeInsets.all(AppSpacing.base),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(SalesChannel.icon(channel), size: 15, color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr(SalesChannel.labelKey(channel)),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sarCompact(totals.net),
            style: AppTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 3,
            children: [
              _miniStat(Icons.trending_up_rounded, sarCompact(totals.profit), AppColors.success),
              _miniStat(Icons.receipt_long_rounded,
                  '${intGrouped(totals.invoices)} ${context.tr('rd_invoices_short')}', AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// One stacked bar: indigo (showrooms) + gold (wholesale) shares of net.
  Widget _shareBar(BuildContext context) {
    final retailShare = channels.retailShare;
    final wholesaleShare = channels.wholesaleShare;
    if (retailShare <= 0 && wholesaleShare <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.borderFull,
          child: SizedBox(
            height: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Row(
                children: [
                  Expanded(
                    flex: ((retailShare * v) * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: SalesChannel.fill(SalesChannel.retail)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((wholesaleShare * v) * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: SalesChannel.fill(SalesChannel.wholesale)),
                  ),
                  // Remaining (un-animated) space collapses as v → 1.
                  if (v < 1)
                    Expanded(
                      flex: (((1 - (retailShare + wholesaleShare) * v)) * 1000).round().clamp(0, 1000),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legend(context, SalesChannel.retail, retailShare),
            const SizedBox(width: AppSpacing.base),
            _legend(context, SalesChannel.wholesale, wholesaleShare),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, String channel, double share) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: SalesChannel.fill(channel), borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          '${context.tr(SalesChannel.labelKey(channel))} ${(share * 100).toStringAsFixed(0)}٪',
          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
