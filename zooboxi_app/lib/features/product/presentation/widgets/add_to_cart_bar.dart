import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/qty_stepper.dart';
import '../../../../l10n/app_localizations.dart';

/// Whether the bar is offering a restock alert instead of a purchase, and
/// where that offer stands.
///
/// [none] is the old behaviour and the default: an out-of-stock product with
/// a dead button. Every other value belongs to a screen that has actually
/// asked the store what this customer is waiting for.
enum NotifyState {
  /// Nothing to offer — the button says «غير متوفّر» and does nothing.
  none,

  /// Not subscribed: the button offers the alert.
  off,

  /// Subscribed: the button says so, and a tap takes it back.
  on,

  /// A read or a toggle is in flight.
  busy,
}

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
    this.notifyState = NotifyState.none,
    this.onNotify,
  });

  final double unitPrice;
  final int qty;
  final int? maxQty;
  final bool outOfStock;
  final bool busy;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;

  /// An out-of-stock product is not the end of the conversation: the bar
  /// turns into «نبّهني عند التوفر» rather than a wall, and the same button
  /// takes the subscription back.
  final NotifyState notifyState;
  final VoidCallback? onNotify;

  /// Where a successful add flies *from*. Held by the screen, since the bar
  /// is rebuilt on every quantity tap.
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final lineTotal = unitPrice * qty;

    // A card, not a wall. The main menu now travels with the customer on to
    // the product page, so this bar is no longer the last thing on screen:
    // the safe-area reservation is taken *outside* the paint, and the ink
    // hugs the controls. That keeps the page visible in the gap between this
    // card and the glass menu beneath it, instead of stacking two slabs.
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: context.isDark ? 0.5 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              Expanded(child: _Button(bar: this, lineTotal: lineTotal, locale: locale)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one button, in the three jobs it does: buy, wait for a restock, or
/// state plainly that neither is on offer.
class _Button extends StatelessWidget {
  const _Button({required this.bar, required this.lineTotal, required this.locale});

  final AddToCartBar bar;
  final double lineTotal;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    // An out-of-stock product with a live restock offer: the alert IS the
    // call to action, and the price line has nothing to say about a box that
    // cannot be bought.
    final notifying = bar.outOfStock && bar.notifyState != NotifyState.none;
    final waiting = bar.notifyState == NotifyState.on;
    final spinning =
        bar.busy || (notifying && bar.notifyState == NotifyState.busy);

    final VoidCallback? onPressed;
    if (spinning) {
      onPressed = null;
    } else if (notifying) {
      onPressed = bar.onNotify;
    } else {
      onPressed = bar.outOfStock ? null : bar.onAdd;
    }

    return FilledButton(
      key: bar.anchorKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        // A subscription already taken is a state, not an invitation — it
        // steps back to the outline weight so the page stops shouting.
        backgroundColor: waiting ? cs.surfaceContainerHigh : null,
        foregroundColor: waiting ? cs.onSurface : null,
      ),
      child: spinning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (notifying) ...[
                  Icon(
                    waiting
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    size: 22,
                  ),
                  Gap.w8,
                  Flexible(
                    child: Text(
                      waiting ? l.pdpNotifyMeOn : l.pdpNotifyMe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (bar.outOfStock)
                  Text(l.pdpOutOfStock)
                else ...[
                  ZbIcon(ZbIconKind.plusBox, size: 24, ink: cs.onPrimary),
                  Gap.w8,
                  Text(l.pdpAddToCart),
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
    );
  }
}
