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
  const FreeShippingBar({super.key, required this.freeShipping});

  final FreeShipping freeShipping;

  @override
  Widget build(BuildContext context) {
    if (!freeShipping.isActive) return const SizedBox.shrink();

    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final qualified = freeShipping.qualified;
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
