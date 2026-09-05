import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../data/cart_models.dart';

/// Progress toward free delivery — or, once a perk has waived it, the
/// celebration instead.
///
/// The bar animates to its new value on every cart change, which is the point:
/// watching the gap close is what makes the extra item feel worth adding. But
/// a waived fee is not a threshold reached: the moment a reward or a tier makes
/// delivery free, the counter goes away entirely and a card says so, because
/// nudging someone toward a number they no longer have to reach is the bar
/// lying to them.
class FreeShippingBar extends StatelessWidget {
  const FreeShippingBar({
    super.key,
    required this.freeShipping,
    this.freeDeliveryReason,
    this.expressFreeReason,
  });

  final FreeShipping freeShipping;

  /// `tier` | `reward` | null — why delivery costs nothing, when it doesn't.
  final String? freeDeliveryReason;

  /// `tier` | `reward` | null — the same, for the express fee alone.
  final String? expressFreeReason;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (freeDeliveryReason != null) {
      return _Celebration(
        kind: 'free_delivery',
        title: l.cartFreeDeliveryCelebrate,
        body: switch (freeDeliveryReason) {
          'reward' => l.rewardFreeDeliveryReward,
          'subscription' => l.subsFreeDeliveryBody,
          _ => l.rewardFreeDeliveryTier,
        },
      );
    }
    if (expressFreeReason != null) {
      // Express is waived but the ordinary threshold may still apply — say
      // both: the celebration, and the bar underneath when it is still live.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Celebration(
            kind: 'express_free',
            title: l.cartExpressCelebrate,
            body: expressFreeReason == 'reward'
                ? l.rewardExpressFreeReward
                : l.rewardExpressFreeTier,
          ),
          if (freeShipping.isActive) ...[
            Gap.h8,
            _Bar(freeShipping: freeShipping),
          ],
        ],
      );
    }
    if (!freeShipping.isActive) return const SizedBox.shrink();
    return _Bar(freeShipping: freeShipping);
  }
}

/// The counter: the sentence and the bar.
class _Bar extends StatelessWidget {
  const _Bar({required this.freeShipping});

  final FreeShipping freeShipping;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final qualified = freeShipping.qualified;
    final accent = qualified ? zb.success : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: qualified ? zb.success.withValues(alpha: context.isDark ? 0.14 : 0.09) : cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(
          color: qualified ? zb.success.withValues(alpha: 0.35) : cs.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              qualified
                  ? FamilyMarkIcon(FamilyMark.check, size: 18, color: accent)
                  : const RewardSticker(kind: 'free_delivery', size: 22),
              Gap.w8,
              Expanded(
                child: Text(
                  qualified
                      ? l.cartFreeShippingQualified
                      : l.cartFreeShippingRemaining(
                          Fmt.price(freeShipping.remaining, locale: locale),
                        ),
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: qualified ? accent : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          Gap.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: freeShipping.progress),
              duration: context.motion(const Duration(milliseconds: 520)),
              curve: Motion.emphasized,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «مبروك» — the perk, as a card with the sticker and sparkles.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.kind, required this.title, required this.body});

  final String kind;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hue = rewardKindHue(context, kind);

    return Container(
      decoration: BoxDecoration(
        gradient: rewardKindWash(context, kind),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: SparkleField(sparkles: _sparkles, twinkle: true)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                RewardSticker(kind: kind, size: 46),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 17, color: hue),
                          Gap.w6,
                          Expanded(
                            child: Text(
                              title,
                              style: context.tt.titleSmall?.copyWith(
                                color: hue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Gap.h4,
                      Text(
                        body,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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

const List<SparkleSpec> _sparkles = [
  SparkleSpec(dx: 0.88, dy: 0.18, size: 12, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 200)),
  SparkleSpec(dx: 0.96, dy: 0.70, size: 8, color: ZbTokens.logoCoral, delay: Duration(milliseconds: 700), rotation: 0.4),
  SparkleSpec(dx: 0.70, dy: 0.84, size: 7, color: ZbTokens.logoTeal, delay: Duration(milliseconds: 1100), rotation: 0.2),
];
