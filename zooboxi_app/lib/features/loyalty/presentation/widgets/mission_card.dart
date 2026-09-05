import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// One of the month's missions.
///
/// A mission is a sticker, a sentence and a ring: what it is about, what to
/// do, and how far along — with the reward as a coin, because the reward is
/// the reason. The ring, not a bar: every mission is a fraction of a small
/// target, and a ring reads as a fraction at a glance.
///
/// [awaitingDelivery] is the honest state between "ordered" and "delivered":
/// the mission looks at zero, but the order that completes it is on its way.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    this.compact = false,
    this.width,
    this.onTap,
    this.awaitingDelivery = false,
  });

  final Mission mission;

  /// The home strip's form: fixed width, no body, no product suggestions.
  final bool compact;
  final double? width;
  final VoidCallback? onTap;
  final bool awaitingDelivery;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final done = mission.isDone;
    final hue = done ? zb.success : missionKindHue(context, mission.kind);
    final waiting = awaitingDelivery && !done;

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(
          color: done ? zb.success.withValues(alpha: 0.40) : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: context.isDark ? 0.0 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StickerTile(kind: mission.kind, done: done, compact: compact),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mission.title,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (!compact && mission.body.isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        mission.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    Gap.h8,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // The strip has one line for a chip: the wait notice
                        // outranks the prize while an order is on its way.
                        if (!(compact && waiting)) _RewardChip(reward: mission.reward, done: done),
                        if (waiting) _WaitingChip(label: l.missionAwaitingDelivery),
                      ],
                    ),
                  ],
                ),
              ),
              Gap.w12,
              _Ring(mission: mission, hue: hue, done: done, waiting: waiting, compact: compact),
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
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: card,
    );
  }
}

/// The sticker on its wash — the mission's face.
class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.kind, required this.done, required this.compact});

  final String kind;
  final bool done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    final dark = context.isDark;
    final side = compact ? 52.0 : 60.0;
    final (Color a, Color b) = switch (kind) {
      'profile' => dark ? (ZbTokens.tealContainerDark, ZbTokens.tealContainerDarkEnd) : (ZbTokens.tealTint, ZbTokens.tealTintSoft),
      'frequency' => dark ? (ZbTokens.coralContainerDark, ZbTokens.coralContainerDarkEnd) : (ZbTokens.coralTint, ZbTokens.coralTintSoft),
      'trial' => dark ? (ZbTokens.amberContainerDark, ZbTokens.amberContainerDarkEnd) : (ZbTokens.amberTint, ZbTokens.amberTintSoft),
      'category' => dark ? (ZbTokens.greenContainerDark, ZbTokens.greenContainerDarkEnd) : (ZbTokens.greenTint, ZbTokens.greenTintSoft),
      _ => dark ? (ZbTokens.expressBgDark, const Color(0xFF2A1810)) : (const Color(0xFFFFE9D6), const Color(0xFFFFF5EC)),
    };

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: done
              ? [zb.success.withValues(alpha: dark ? 0.28 : 0.16), zb.success.withValues(alpha: dark ? 0.16 : 0.08)]
              : [a, b],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      alignment: Alignment.center,
      child: MissionSticker(kind: kind, size: side * 0.72),
    );
  }
}

/// What the mission pays: the coin and the count, or the reward's sticker.
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.reward, required this.done});

  final MissionReward reward;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dark = context.isDark;
    final fg = dark ? ZbTokens.amberOnDark : const Color(0xFF8A5F08);

    final Widget icon;
    final String label;
    final Color tint;
    if (reward.isPaws) {
      icon = const PawCoin(size: 16);
      label = l.rewardCost(Fmt.number(reward.paws, locale: locale, decimals: 0));
      tint = fg;
    } else {
      final gift = reward.reward!;
      icon = RewardSticker(kind: gift.kind, size: 16);
      label = gift.title.isEmpty ? l.missionRewardGift : gift.title;
      tint = rewardKindHue(context, gift.kind);
    }

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: reward.isPaws
            ? (dark ? ZbTokens.amberContainerDark : const Color(0xFFFCEFCF))
            : tint.withValues(alpha: dark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          Gap.w4,
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: zb.warning.withValues(alpha: context.isDark ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FamilyMarkIcon(FamilyMark.clock, size: 14),
          Gap.w4,
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: context.isDark ? zb.warning : const Color(0xFF8A5510),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ring with the count inside — or the check once it is done.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.mission,
    required this.hue,
    required this.done,
    required this.waiting,
    required this.compact,
  });

  final Mission mission;
  final Color hue;
  final bool done;
  final bool waiting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final size = compact ? 46.0 : 54.0;

    return ProgressRing(
      value: done ? 1 : mission.ratio,
      color: waiting ? context.zb.warning : hue,
      size: size,
      stroke: compact ? 4.5 : 5.5,
      child: done
          ? FamilyMarkIcon(FamilyMark.check, size: size * 0.5, color: hue)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Fmt.number(mission.progress, locale: locale, decimals: 0),
                  style: (compact ? context.tt.titleSmall : context.tt.titleMedium)?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  l.missionOfTarget(Fmt.number(mission.target, locale: locale, decimals: 0)),
                  style: context.tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.0,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 86,
            child: PressScale(
              onTap: () => context.push('/product/${product.id}', extra: product),
              borderRadius: BorderRadius.circular(ZbTokens.rSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 86,
                    height: 68,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(ZbTokens.rSm),
                    ),
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
