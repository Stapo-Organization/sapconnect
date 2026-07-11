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
/// cards (indigo showrooms / gold wholesale) with count-up nets, a crown on
/// the leading channel, and an animated split bar with a knob riding the
/// boundary. Tapping a card drills into that channel's dedicated view.
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
    final retailLeads = channels.retail.net >= channels.wholesale.net;
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
                leader: retailLeads,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _channelCard(
                context,
                channel: SalesChannel.wholesale,
                totals: channels.wholesale,
                leader: !retailLeads,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _shareBar(context),
      ],
    );
  }

  Widget _channelCard(
    BuildContext context, {
    required String channel,
    required ChannelTotals totals,
    required bool leader,
  }) {
    final color = SalesChannel.color(channel);
    final fill = SalesChannel.fill(channel);
    return AppCard(
      onTap: () => onOpenChannel(channel),
      padding: EdgeInsets.zero,
      borderColor: color.withValues(alpha: 0.25),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: SalesChannel.wash(channel),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [fill, Color.lerp(fill, Colors.black, 0.22)!],
                    ),
                    borderRadius: AppRadius.borderSm,
                    boxShadow: [
                      BoxShadow(
                        color: fill.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(SalesChannel.icon(channel), size: 15, color: Colors.white),
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
                // تاج القناة المتصدرة — قراءة فورية لمن يكسب الفترة.
                if (leader)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 2),
                    child: Icon(Icons.workspace_premium_rounded, size: 15, color: color),
                  ),
                Icon(
                  AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: totals.net),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                sarCompact(v),
                style: AppTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
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

  /// شريط الانقسام: نيلي (معارض) + ذهبي (جملة) بتدرّج، ومقبض أبيض يركب نقطة
  /// الحدود بينهما ويتحرّك معها أثناء التمدد.
  Widget _shareBar(BuildContext context) {
    final retailShare = channels.retailShare;
    final wholesaleShare = channels.wholesaleShare;
    if (retailShare <= 0 && wholesaleShare <= 0) return const SizedBox.shrink();
    final retailFill = SalesChannel.fill(SalesChannel.retail);
    final wholesaleFill = SalesChannel.fill(SalesChannel.wholesale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.borderFull,
                      child: SizedBox(
                        height: 12,
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              flex: ((retailShare * v) * 1000).round().clamp(1, 1000),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    retailFill,
                                    Color.lerp(retailFill, Colors.white, 0.18)!,
                                  ]),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: ((wholesaleShare * v) * 1000).round().clamp(1, 1000),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Color.lerp(wholesaleFill, Colors.white, 0.18)!,
                                    wholesaleFill,
                                  ]),
                                ),
                              ),
                            ),
                            // Remaining (un-animated) space collapses as v → 1.
                            if (v < 1)
                              Expanded(
                                flex: (((1 - (retailShare + wholesaleShare) * v)) * 1000)
                                    .round()
                                    .clamp(0, 1000),
                                child: ColoredBox(color: AppColors.borderLight),
                              ),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: (retailShare * v * w - 8).clamp(0.0, w - 16),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 7),
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
          context.tr(SalesChannel.labelKey(channel)),
          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          pctLabel(share * 100),
          style: AppTypography.labelSmall.copyWith(
            color: SalesChannel.color(channel),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
