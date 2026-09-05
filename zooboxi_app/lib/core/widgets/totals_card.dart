import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/cart/data/cart_models.dart';
import '../../l10n/app_localizations.dart';
import '../icons/zb_icons.dart';
import '../utils/formatters.dart';

/// Subtotal → discount → delivery → tax → total.
///
/// One widget for the cart, the checkout review and the order receipt: a
/// customer who sees three different money layouts in one purchase stops
/// trusting the number, and the three would drift apart the first time a line
/// was added to only one of them.
class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.totals,
    this.padding = const EdgeInsets.all(14),
    this.bordered = true,
    this.pawsToEarn = 0,
  });

  final CartTotals totals;
  final EdgeInsetsGeometry padding;

  /// False inside a surface that already draws its own frame.
  final bool bordered;

  /// Paws this basket earns *on delivery*. Shown under the total because it
  /// is not money — it must never look like it changes what is owed.
  final int pawsToEarn;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    final rows = Column(
      children: [
        _TotalRow(label: l.cartSubtotal, value: Fmt.price(totals.subtotal, locale: locale)),
        if (totals.discount > 0)
          _TotalRow(
            label: l.cartDiscount,
            value: '-${Fmt.price(totals.discount, locale: locale)}',
            highlight: context.zb.sale,
          ),
        _TotalRow(
          label: l.cartShipping,
          value: totals.shipping <= 0
              ? l.cartFree
              : Fmt.price(totals.shipping, locale: locale),
          highlight: totals.shipping <= 0 ? context.zb.success : null,
        ),
        if (totals.tax > 0)
          _TotalRow(label: l.cartTax, value: Fmt.price(totals.tax, locale: locale)),
        Divider(height: 20, color: cs.outlineVariant),
        _TotalRow(
          label: l.cartTotal,
          value: Fmt.price(totals.total, locale: locale),
          bold: true,
        ),
        if (pawsToEarn > 0) ...[
          const SizedBox(height: 8),
          _PawsEarnRow(paws: pawsToEarn),
        ],
      ],
    );

    if (!bordered) return Padding(padding: padding, child: rows);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: padding,
      child: rows,
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.tt.titleMedium : context.tt.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: bold ? context.cs.onSurface : context.cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: style?.copyWith(
              color: highlight ?? context.cs.onSurface,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "You'll earn N paws" — the quiet reward line under the money.
class _PawsEarnRow extends StatelessWidget {
  const _PawsEarnRow({required this.paws});

  final int paws;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(ZbTokens.rSm),
      ),
      child: Row(
        children: [
          ZbIcon(ZbIconKind.paw, size: 16, fill: 1, tint: cs.primary, ink: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              L.of(context).pawsToEarn(
                    paws,
                    Fmt.number(paws, locale: locale, decimals: 0),
                  ),
              style: context.tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
