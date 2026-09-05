import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// One catalog reward: what it is, what it costs, and — when it can't be
/// taken yet — the reason why.
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
    final hue = rewardKindHue(context, reward.kind);
    final affordable = balance >= reward.pawsCost;
    final enabled = reward.redeemable && affordable && onRedeem != null;

    // A gift with no product behind it is the owner's unfinished work, not
    // the customer's problem: it says "soon", never the admin reason.
    final blocked = !reward.redeemable
        ? (reward.isGift && reward.product == null
              ? l.rewardComingSoon
              : reward.reasonFor(locale) ?? l.rewardTierRequired)
        : (!affordable ? l.rewardInsufficientPaws : null);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: context.isDark ? 0 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // IntrinsicHeight: the wash must run the full height of the text column,
      // and the card lives in a list whose height is unbounded.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The sticker's own wash runs the full height of the card — the
            // reward is the picture first, the sentence second.
            Container(
              width: 104,
              decoration: BoxDecoration(
                gradient: rewardKindWash(context, reward.kind),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: PawPattern(
                      color: Colors.black,
                      opacity: 0.04,
                      scale: 0.6,
                    ),
                  ),
                  RewardSticker(kind: reward.kind, size: 66),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rewardKindLabel(l, reward.kind),
                      style: context.tt.labelSmall?.copyWith(
                        color: hue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Gap.h4,
                    Text(
                      reward.title,
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (reward.description.isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        reward.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    Gap.h8,
                    Row(
                      children: [
                        CostChip(paws: reward.pawsCost),
                        Gap.w8,
                        Expanded(
                          child: Text(
                            [
                              if (reward.valueSar > 0)
                                l.rewardValue(
                                  Fmt.price(reward.valueSar, locale: locale),
                                ),
                              if (reward.validityDays > 0)
                                l.rewardValidity(reward.validityDays),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap.h12,
                    Row(
                      children: [
                        Expanded(
                          child: blocked == null
                              ? const SizedBox.shrink()
                              : Text(
                                  blocked,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.tt.labelSmall?.copyWith(
                                    color: context.zb.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        Gap.w8,
                        FilledButton(
                          onPressed: enabled ? onRedeem : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: hue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Text(l.rewardRedeem),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cost as a chip: the coin, the count, the unit.
class CostChip extends StatelessWidget {
  const CostChip({super.key, required this.paws, this.onColored = false});

  final int paws;

  /// On a coloured tile: frosted white instead of amber.
  final bool onColored;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dark = context.isDark;
    final fg = onColored
        ? Colors.white
        : (dark ? ZbTokens.amberOnDark : const Color(0xFF8A5F08));
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 9, 3),
      decoration: BoxDecoration(
        color: onColored
            ? Colors.white.withValues(alpha: 0.22)
            : (dark ? ZbTokens.amberContainerDark : const Color(0xFFFCEFCF)),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PawCoin(size: 17),
          Gap.w4,
          Text(
            l.rewardCost(Fmt.number(paws, locale: locale, decimals: 0)),
            style: context.tt.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A reward on the hub's shelf: a tall tile with the sticker on its wash,
/// the title, and the cost. Tapping goes to the catalogue.
class RewardShelfTile extends StatelessWidget {
  const RewardShelfTile({
    super.key,
    required this.reward,
    required this.balance,
    required this.onTap,
    this.width = 150,
  });

  final Reward reward;
  final int balance;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final affordable = balance >= reward.pawsCost && reward.redeemable;
    final hue = rewardKindHue(context, reward.kind);

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: rewardKindWash(context, reward.kind),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: PawPattern(
                      color: Colors.black,
                      opacity: 0.04,
                      scale: 0.6,
                    ),
                  ),
                  RewardSticker(kind: reward.kind, size: 64),
                  if (affordable)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hue,
                          borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        ),
                        child: Text(
                          l.rewardsShelfHint,
                          style: context.tt.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  Gap.h8,
                  CostChip(paws: reward.pawsCost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tinted well a reward sticker sits in, for the places that need one
/// small mark (the claim sheet, a cart line).
class RewardGlyphWell extends StatelessWidget {
  const RewardGlyphWell({super.key, required this.kind, this.size = 56});

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: rewardKindWash(context, kind),
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
    ),
    alignment: Alignment.center,
    child: RewardSticker(kind: kind, size: size * 0.68),
  );
}
