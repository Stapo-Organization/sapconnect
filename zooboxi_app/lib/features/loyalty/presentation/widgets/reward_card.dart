import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'reward_glyph.dart';

/// One catalog reward: what it is, what it costs, and — when it can't be
/// taken yet — the server's own reason why.
///
/// The cost is never framed as a price and the value never as a discount:
/// this program buys gifts and services with paws, and the wording has to keep
/// that line clean or the wholesale channel pays for it.
class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.reward,
    required this.balance,
    this.onRedeem,
  });

  final Reward reward;

  /// The wallet, so an unaffordable reward can say so before the tap.
  final int balance;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final tint = rewardKindTint(context, reward.kind);
    final affordable = balance >= reward.pawsCost;
    final enabled = reward.redeemable && affordable && onRedeem != null;

    final blocked = !reward.redeemable
        ? reward.reasonFor(locale) ?? l.rewardTierRequired
        : (!affordable ? l.rewardInsufficientPaws : null);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlyphWell(kind: reward.kind, tint: tint),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rewardKindLabel(l, reward.kind),
                  style: context.tt.labelSmall?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap.h4,
                Text(
                  reward.title,
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (reward.description.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    reward.description,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                Gap.h8,
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l.rewardCost(Fmt.number(reward.pawsCost, locale: locale, decimals: 0)),
                      style: context.tt.labelLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (reward.valueSar > 0)
                      Text(
                        l.rewardValue(Fmt.price(reward.valueSar, locale: locale)),
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    if (reward.validityDays > 0)
                      Text(
                        l.rewardValidity(reward.validityDays),
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
                if (blocked != null) ...[
                  Gap.h8,
                  Text(
                    blocked,
                    style: context.tt.labelSmall?.copyWith(color: context.zb.warning),
                  ),
                ],
                Gap.h12,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonal(
                    onPressed: enabled ? onRedeem : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(l.rewardRedeem),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The tinted disc a reward glyph sits in. Shared by the catalog and the
/// grants list so an owned reward looks like the one it came from.
class _GlyphWell extends StatelessWidget {
  const _GlyphWell({required this.kind, required this.tint});

  final String kind;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: context.isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
        ),
        alignment: Alignment.center,
        child: RewardGlyph(kind: kind, size: 28),
      );
}

/// Exposed so the grant card draws the identical well rather than a near-miss.
class RewardGlyphWell extends StatelessWidget {
  const RewardGlyphWell({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) =>
      _GlyphWell(kind: kind, tint: rewardKindTint(context, kind));
}
