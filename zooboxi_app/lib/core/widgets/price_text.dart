import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../l10n/app_localizations.dart';
import '../utils/formatters.dart';

/// The app's one way to render a price.
///
/// Handles the three things every commerce price needs and most apps get
/// wrong: the Riyal glyph (rendered from the bundled font, sized down slightly
/// so it optically matches the digits), the struck-through original when
/// something is on sale, and the "starts from" prefix for variable products
/// where the shown number is the cheapest variant, not *the* price.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.regularPrice,
    this.onSale = false,
    this.priceFrom = false,
    this.style,
    this.compareStyle,
    this.color,
    this.align = TextAlign.start,
  });

  final double price;
  final double? regularPrice;
  final bool onSale;

  /// Prefixes "يبدأ من" — a variable product's cheapest variant.
  final bool priceFrom;

  final TextStyle? style;
  final TextStyle? compareStyle;
  final Color? color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cs = context.cs;

    final base = (style ?? context.tt.titleMedium ?? const TextStyle()).copyWith(
      color: color ?? cs.onSurface,
      fontWeight: FontWeight.w700,
    );

    final showCompare =
        onSale && regularPrice != null && regularPrice! > price;

    final compare = (compareStyle ?? context.tt.bodySmall ?? const TextStyle()).copyWith(
      color: cs.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
      decorationColor: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment:
          align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (priceFrom)
          Text(
            l.priceFrom,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        RichText(
          textAlign: align,
          text: TextSpan(
            style: base,
            children: [
              TextSpan(text: Fmt.number(price, locale: locale)),
              const TextSpan(text: ' '),
              // The Riyal glyph carries more optical weight than the digits at
              // the same point size, so it is nudged down to sit level.
              TextSpan(
                text: riyalSymbol,
                style: base.copyWith(fontSize: (base.fontSize ?? 15) * 0.86),
              ),
            ],
          ),
        ),
        if (showCompare) ...[
          const SizedBox(height: 2),
          Text('${Fmt.number(regularPrice!, locale: locale)} $riyalSymbol', style: compare),
        ],
      ],
    );
  }
}

/// The "-25%" pill that sits next to a sale price. Coral, because discount is
/// the one place the warm half of the brand earns the attention.
class DiscountPill extends StatelessWidget {
  const DiscountPill({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();
    final l = L.of(context);
    final zb = context.zb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: zb.sale.withValues(alpha: context.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l.priceOff(percent),
        style: context.tt.labelSmall?.copyWith(color: zb.sale, fontWeight: FontWeight.w700),
      ),
    );
  }
}
