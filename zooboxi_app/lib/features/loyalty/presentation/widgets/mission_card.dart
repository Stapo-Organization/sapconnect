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
/// A mission is a **medal**: the sticker sits inside its own progress ring,
/// with the count hung under it like a ribbon tag, so one object answers both
/// "what is this about?" and "how far am I?". Everything else is one column —
/// the sentence, and the prize as a coin badge on the title's line — which is
/// what keeps the card two rows tall instead of four.
///
/// A finished mission drops its explanation: it has been read, it has been
/// done, and what is left to say is the check on the medal.
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
    final dark = context.isDark;

    // The mission's own colour, barely there — enough that four cards read as
    // four different missions rather than four identical rectangles.
    final wash = hue.withValues(alpha: dark ? 0.13 : 0.09);

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [Color.alphaBlend(wash, cs.surface), cs.surface],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(
          color: done ? zb.success.withValues(alpha: 0.40) : cs.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: dark ? 0.0 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 11 : 14,
        compact ? 10 : 12,
        compact ? 11 : 14,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Medal(
                mission: mission,
                hue: hue,
                done: done,
                waiting: waiting,
                compact: compact,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // On the strip the title gets the whole line and the
                    // chip drops beneath it. It costs nothing: the row's
                    // height is set by the medal beside it, and «أول طلب من
                    // التطبيق» does not fit next to a chip on a 268pt card.
                    if (compact) ...[
                      Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      Gap.h4,
                      // One chip fits here, and while an order is on its way
                      // the wait notice outranks the prize — it is the answer
                      // to "why is this still at zero?".
                      if (waiting)
                        _WaitingChip(label: l.missionAwaitingDelivery)
                      else
                        _RewardChip(reward: mission.reward, done: done),
                    ] else ...[
                      // The prize rides the title's line: it is the reason the
                      // mission exists, and it costs no row of its own.
                      //
                      // A ceiling, not a share: two flex children split the
                      // row by ratio and hand nothing back, so a «150 بصمة»
                      // chip would keep 40% of the line while the title
                      // truncated beside it. The chip may take up to half when
                      // a gift reward carries a whole sentence for a label,
                      // and every point it does not need is the title's.
                      LayoutBuilder(
                        builder: (context, row) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                mission.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Gap.w8,
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: row.maxWidth * 0.5),
                              child: _RewardChip(reward: mission.reward, done: done),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // A finished mission has nothing left to explain.
                    if (!compact && !done && mission.body.isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        mission.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (waiting && !compact) ...[
                      Gap.h4,
                      _WaitingChip(label: l.missionAwaitingDelivery),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!compact && !done && mission.suggestedProducts.isNotEmpty) ...[
            Gap.h12,
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

/// The mission as one object: its sticker inside its own progress ring, with
/// the count hung underneath like the tag on a medal's ribbon.
class _Medal extends StatelessWidget {
  const _Medal({
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
    final locale = Localizations.localeOf(context).languageCode;
    final zb = context.zb;
    final cs = context.cs;
    final dark = context.isDark;
    final side = compact ? 50.0 : 58.0;
    final ring = waiting ? zb.warning : hue;

    return SizedBox(
      width: side,
      // The tag hangs past the ring; the box keeps the row's height honest.
      height: side + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ProgressRing(
            value: done ? 1 : mission.ratio,
            color: ring,
            size: side,
            stroke: compact ? 4 : 4.5,
            child: Container(
              width: side * 0.66,
              height: side * 0.66,
              decoration: BoxDecoration(
                color: ring.withValues(alpha: dark ? 0.18 : 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: MissionSticker(kind: mission.kind, size: side * 0.5),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            child: _CountTag(
              done: done,
              hue: ring,
              label: done
                  ? null
                  : '${Fmt.number(mission.progress, locale: locale, decimals: 0)}'
                      '/${Fmt.number(mission.target, locale: locale, decimals: 0)}',
              surface: cs.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// «1/3» — or the check that replaces it.
class _CountTag extends StatelessWidget {
  const _CountTag({
    required this.done,
    required this.hue,
    required this.label,
    required this.surface,
  });

  final bool done;
  final Color hue;
  final String? label;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    // The check mark paints its own disc and tick; it is a seal, not a glyph,
    // so it sits on the ring bare with a rim of the card behind it.
    if (done) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
        child: FamilyMarkIcon(FamilyMark.check, size: 18, color: context.zb.success),
      );
    }

    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: hue,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(color: surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label!,
        style: context.tt.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
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

/// The shortest path from reading a mission to finishing it.
///
/// Three faces and a price, not three product cards: the mission's job is to
/// point, and a full card here would make the mission taller than the thing it
/// is asking for.
class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({required this.products});

  final List<ProductCard> products;

  static const double _thumb = 46;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final shown = products.take(3).toList();

    return Row(
      children: [
        Text(
          l.missionSuggested,
          style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Gap.w8,
        for (final product in shown) ...[
          PressScale(
            onTap: () => context.push('/product/${product.id}', extra: product),
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            child: Tooltip(
              message: product.name,
              child: Container(
                width: _thumb,
                height: _thumb,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(ZbTokens.rMd),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ZbImage(
                  url: product.image,
                  radius: BorderRadius.circular(ZbTokens.rMd),
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ),
          Gap.w6,
        ],
        const Spacer(),
        // The cheapest of the three, said the way the shop says it — a bare
        // number beside three faces reads as the price of the first one.
        Text(
          '${l.priceFrom} ${Fmt.price(shown.map((p) => p.price).reduce((a, b) => a < b ? a : b), locale: locale)}',
          style: context.tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
