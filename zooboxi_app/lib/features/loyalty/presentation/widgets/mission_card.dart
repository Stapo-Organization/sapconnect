import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';
import '../../data/loyalty_models.dart';
import 'paws_pill.dart';
import 'reward_glyph.dart';

/// One of the month's missions.
///
/// A mission is a sentence and a bar: what to do, how far along, what it pays.
/// The suggested products live *inside* the card rather than in a rail of
/// their own, because they are the answer to this mission — not merchandising.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    this.compact = false,
    this.width,
    this.onTap,
  });

  final Mission mission;

  /// The home strip's form: fixed width, no product suggestions.
  final bool compact;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final done = mission.isDone;
    final accent = done ? zb.success : cs.primary;

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(
          color: done ? zb.success.withValues(alpha: 0.42) : cs.outlineVariant,
        ),
      ),
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Gap.w8,
              _RewardBadge(reward: mission.reward, compact: compact),
            ],
          ),
          if (!compact && mission.body.isNotEmpty) ...[
            Gap.h4,
            Text(
              mission.body,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          Gap.h12,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: mission.ratio),
              duration: context.motion(const Duration(milliseconds: 560)),
              curve: Motion.emphasized,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          Gap.h8,
          Row(
            children: [
              if (done)
                Icon(Icons.check_circle_rounded, size: 15, color: zb.success)
              else
                const SizedBox.shrink(),
              if (done) Gap.w4,
              Text(
                done ? l.missionDone : l.missionProgress(mission.progress, mission.target),
                style: context.tt.labelMedium?.copyWith(
                  color: done ? zb.success : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (!compact && mission.suggestedProducts.isNotEmpty) ...[
            Gap.h12,
            Text(
              l.missionSuggested,
              style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.h8,
            _SuggestionStrip(products: mission.suggestedProducts),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: card,
    );
  }
}

/// What the mission pays, as one small mark: the paw count, or the reward's
/// own glyph for a gift or a delivery perk.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.reward, required this.compact});

  final MissionReward reward;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (reward.isPaws) {
      return PawsPill(paws: reward.paws, compact: true, showUnit: !compact);
    }
    final gift = reward.reward!;
    final tint = rewardKindTint(context, gift.kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: context.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RewardGlyph(kind: gift.kind, size: 15),
          Gap.w4,
          Text(
            L.of(context).missionRewardGift,
            style: context.tt.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shortest path from reading a mission to finishing it.
class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({required this.products});

  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 82,
            child: PressScale(
              onTap: () => context.push('/product/${product.id}', extra: product),
              borderRadius: BorderRadius.circular(ZbTokens.rSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    height: 66,
                    child: ZbImage(
                      url: product.image,
                      radius: BorderRadius.circular(ZbTokens.rSm),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                  Gap.h4,
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    Fmt.price(product.price, locale: locale),
                    style: context.tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
