import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/qty_stepper.dart';
import '../../../../l10n/app_localizations.dart';

/// The pinned purchase bar.
///
/// It shows the *line* total, not the unit price: once a quantity is chosen,
/// the number that matters is what this tap will cost. The stepper is capped
/// by what the server says can actually reach the customer.
class AddToCartBar extends StatelessWidget {
  const AddToCartBar({
    super.key,
    required this.unitPrice,
    required this.qty,
    required this.maxQty,
    required this.outOfStock,
    required this.busy,
    required this.onQty,
    required this.onAdd,
    this.anchorKey,
  });

  final double unitPrice;
  final int qty;
  final int? maxQty;
  final bool outOfStock;
  final bool busy;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;

  /// Where a successful add flies *from*. Held by the screen, since the bar
  /// is rebuilt on every quantity tap.
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final lineTotal = unitPrice * qty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: context.isDark ? 0.5 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (!outOfStock) ...[
                QtyStepper(
                  value: qty,
                  max: maxQty,
                  onChanged: onQty,
                  busy: false,
                ),
                Gap.w12,
              ],
              Expanded(
                child: FilledButton(
                  key: anchorKey,
                  onPressed: outOfStock || busy ? null : onAdd,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!outOfStock) ...[
                              ZbIcon(
                                ZbIconKind.plusBox,
                                size: 24,
                                ink: cs.onPrimary,
                              ),
                              Gap.w8,
                            ],
                            Text(outOfStock ? l.pdpOutOfStock : l.pdpAddToCart),
                            if (!outOfStock) ...[
                              Gap.w8,
                              Container(
                                width: 1,
                                height: 16,
                                color: cs.onPrimary.withValues(alpha: 0.32),
                              ),
                              Gap.w8,
                              Text(Fmt.price(lineTotal, locale: locale)),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
