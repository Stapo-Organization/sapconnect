import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/cart/data/cart_models.dart';
import '../../l10n/app_localizations.dart';
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
  });

  final CartTotals totals;
  final EdgeInsetsGeometry padding;

  /// False inside a surface that already draws its own frame.
  final bool bordered;

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
