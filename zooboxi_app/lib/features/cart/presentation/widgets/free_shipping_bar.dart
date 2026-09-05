import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/cart_models.dart';

/// Progress toward free delivery.
///
/// The bar animates to its new value on every cart change, which is the point:
/// watching the gap close is what makes the extra item feel worth adding. Once
/// qualified it turns celebratory rather than simply disappearing.
class FreeShippingBar extends StatelessWidget {
  const FreeShippingBar({
    super.key,
    required this.freeShipping,
    this.freeDeliveryReason,
    this.expressFreeReason,
  });

  final FreeShipping freeShipping;

  /// `tier` | `reward` | null — why delivery costs nothing, when it doesn't.
  /// Saying which is what turns a perk into something the customer can feel
  /// they earned rather than a number that happened to be zero.
  final String? freeDeliveryReason;

  /// `tier` | `reward` | null — the same, for the express fee alone.
  final String? expressFreeReason;

  /// The one sentence that explains a waived fee, or null when nothing was.
  String? _reasonText(L l) => switch ((freeDeliveryReason, expressFreeReason)) {
        ('tier', _) => l.rewardFreeDeliveryTier,
        ('reward', _) => l.rewardFreeDeliveryReward,
        (_, 'tier') => l.rewardExpressFreeTier,
        (_, 'reward') => l.rewardExpressFreeReward,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final reason = _reasonText(l);
    if (!freeShipping.isActive && reason == null) return const SizedBox.shrink();

    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    // A granted perk *is* qualification: nudging someone toward a threshold
    // they no longer have to reach is the bar lying to them.
    final qualified = freeShipping.qualified || freeDeliveryReason != null;
    final accent = qualified ? zb.success : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: qualified
            ? zb.success.withValues(alpha: context.isDark ? 0.14 : 0.09)
            : cs.surface,
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
              Icon(
                qualified ? Icons.check_circle_rounded : Icons.local_shipping_outlined,
                size: 17,
                color: accent,
              ),
              Gap.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    if (reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          reason,
                          style: context.tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (freeShipping.isActive) ...[
            Gap.h8,
            _Progress(progress: freeShipping.progress, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: context.motion(const Duration(milliseconds: 520)),
        curve: Motion.emphasized,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      ),
    );
  }
}
