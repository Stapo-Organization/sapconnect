import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/live_tracking.dart';
import '../../data/order_models.dart';
import 'live_tracking_card.dart' show livePhaseColor, liveStatusLine;
import 'order_status_pill.dart';

/// The one thing this order lets the customer DO from the list.
///
/// Exactly one, chosen by what the order needs rather than by what is
/// possible: an unpaid order needs paying before anything else, an order on a
/// motorbike needs following, and an order that is over is a shopping list.
enum OrderAction { none, pay, track, reorder }

/// One order in «طلباتي».
///
/// The old row was a receipt: a number, a date, a strip of thumbnails, a price.
/// It answered "what did I buy" and nothing else, so every question — *where is
/// it*, *do I still owe for it*, *can I have it again* — cost a tap into the
/// order and a tap back out.
///
/// This one leads with state. A coloured rail down the reading edge gives the
/// list a scannable rhythm before a word is read, the order that is actually
/// moving wears a live strip with its courier's own sentence, and the footer
/// carries the single action the order is asking for.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.live,
    this.onTap,
    this.onAction,
    this.busy = false,
  });

  final OrderSummary order;

  /// Set only on the order the customer is waiting on right now — the same
  /// payload the bar above the tab bar is already polling, never a second call.
  final LiveTracking? live;

  final VoidCallback? onTap;
  final void Function(OrderAction action)? onAction;

  /// A reorder in flight. The button holds its place and spins rather than
  /// vanishing, so the card does not resize under the customer's thumb.
  final bool busy;

  OrderAction get action {
    if (order.awaitsPayment) return OrderAction.pay;
    if (live != null && live!.isLive) return OrderAction.track;
    if (order.status == 'zb-out-for-delivery') return OrderAction.track;
    // «اطلبها مجددًا» belongs to orders that are OVER. Offering it on an order
    // still being packed invites a duplicate the customer did not mean.
    if (order.canReorder &&
        const {'completed', 'cancelled', 'refunded'}.contains(order.status)) {
      return OrderAction.reorder;
    }
    return OrderAction.none;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tone = live != null
        ? livePhaseColor(context, live!.phase)
        : orderStatusColors(context, order.status).$1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: PressScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          // The content sizes the card; the rail is positioned against it, so
          // it runs the full height — live strip included — without needing a
          // height of its own. (A stretched Row cannot: inside a scroll view
          // the incoming height is infinite.)
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (live != null) _LiveStrip(tracking: live!, tone: tone),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Head(order: order, live: live != null),
                          Gap.h12,
                          _Goods(order: order),
                          Gap.h12,
                          Divider(height: 1, color: cs.outlineVariant),
                          const SizedBox(height: 10),
                          _Foot(
                            order: order,
                            action: action,
                            busy: busy,
                            onAction: onAction,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: tone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── The strip that says something is happening ─────────────────── */

/// The courier's own sentence, at the top of the order he is carrying.
///
/// The list is a history; exactly one row in it is a live event, and it should
/// not have to be found. The strip is the order's phase colour, and it carries
/// the same words as the tracking screen so the two never disagree.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.tracking, required this.tone});

  final LiveTracking tracking;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final eta = tracking.etaMinutes;

    return Container(
      width: double.infinity,
      color: tone.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
      child: Row(
        children: [
          _Beacon(tone: tone),
          Gap.w10,
          Expanded(
            child: Text(
              liveStatusLine(context, tracking),
              style: context.tt.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (eta != null && eta >= 0 && eta <= 120) ...[
            Gap.w8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
              ),
              child: Text(
                eta == 0 ? l.liveTrackEtaNow : l.liveTrackEta(eta),
                style: context.tt.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dot inside its own halo — the quietest way to say «هذا يتحرّك».
///
/// Deliberately not animated: this sits in a scrolling list, and a pulse on a
/// row that is being flung reads as a rendering fault rather than as life. The
/// minutes beside it change on their own every few seconds, which is the real
/// evidence.
class _Beacon extends StatelessWidget {
  const _Beacon({required this.tone});

  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.withValues(alpha: 0.28),
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
          ),
        ),
      );
}

/* ── Number, date, state ────────────────────────────────────────── */

class _Head extends StatelessWidget {
  const _Head({required this.order, required this.live});

  final OrderSummary order;

  /// The strip above already says «مندوبك في الطريق إليك». Repeating it as a
  /// pill two lines lower is the same news twice, in smaller type.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '#${order.number}',
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.deliveryType == 'express') ...[
                    Gap.w8,
                    const _ExpressChip(),
                  ],
                ],
              ),
              if (order.date != null) ...[
                Gap.h4,
                Text(
                  Fmt.dayTime(order.date!, locale),
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (!live) ...[
          Gap.w8,
          OrderStatusPill(order: order, compact: true),
        ],
      ],
    );
  }
}

/// «إكسبريس» — worth its own mark on the card, because it is the reason the
/// order arrived in two hours and the reason the next one might.
class _ExpressChip extends StatelessWidget {
  const _ExpressChip();

  @override
  Widget build(BuildContext context) {
    final pair = context.zb.tierExpress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: pair.bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: pair.fg),
          const SizedBox(width: 2),
          Text(
            L.of(context).shelfExpressTab,
            style: context.tt.labelSmall?.copyWith(
              color: pair.fg,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── What was in it ─────────────────────────────────────────────── */

/// Overlapped photographs and the first product's name.
///
/// A row of separate squares spent 48pt of height saying "there were things in
/// this order". Stacked, the same photographs cost 40 and read as one object —
/// and the space bought back goes to the product's NAME, which is how a
/// customer actually recognises the order they are looking for.
class _Goods extends StatelessWidget {
  const _Goods({required this.order});

  final OrderSummary order;

  static const double _size = 40;
  static const double _step = 28;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final shown = order.itemsPreview.take(3).toList();
    // Distinct products, never units: «+5» beside one photograph of a carton
    // of six would be five photographs that do not exist.
    final extra = order.itemsLines - shown.length;

    if (shown.isEmpty) {
      return Text(
        l.cartItems(order.itemsCount),
        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: _size + (shown.length - 1) * _step + (extra > 0 ? _step : 0),
          height: _size,
          child: Stack(
            children: [
              for (var i = shown.length - 1; i >= 0; i--)
                PositionedDirectional(
                  start: i * _step,
                  child: _Thumb(url: shown[i].image),
                ),
              if (extra > 0)
                PositionedDirectional(
                  start: shown.length * _step,
                  child: _Thumb(
                    label: l.ordersMorePhotos(extra),
                  ),
                ),
            ],
          ),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shown.first.name,
                style: context.tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                l.cartItems(order.itemsCount),
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One photograph in the stack: a white disc with a ring, so overlapping tins
/// stay separate objects instead of becoming a smear.
class _Thumb extends StatelessWidget {
  const _Thumb({this.url, this.label});

  final String? url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      width: _Goods._size,
      height: _Goods._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: label == null ? cs.surface : cs.surfaceContainerHigh,
        border: Border.all(color: cs.surface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: label != null
          ? Center(
              child: Text(
                label!,
                textDirection: TextDirection.ltr,
                style: context.tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : ZbImage(url: url, padding: const EdgeInsets.all(3)),
    );
  }
}

/* ── Money, and the one thing to do about it ────────────────────── */

class _Foot extends StatelessWidget {
  const _Foot({
    required this.order,
    required this.action,
    required this.busy,
    required this.onAction,
  });

  final OrderSummary order;
  final OrderAction action;
  final bool busy;
  final void Function(OrderAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;

    return Row(
      children: [
        Expanded(
          child: Text(
            Fmt.price(order.total, locale: locale),
            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Gap.w8,
        switch (action) {
          OrderAction.pay => _Action(
              label: l.orderPayNow,
              icon: Icons.credit_card_rounded,
              fg: Colors.white,
              bg: zb.warning,
              onTap: () => onAction?.call(OrderAction.pay),
            ),
          OrderAction.track => _Action(
              label: l.liveTrackTitle,
              icon: Icons.near_me_rounded,
              fg: Colors.white,
              bg: cs.primary,
              onTap: () => onAction?.call(OrderAction.track),
            ),
          OrderAction.reorder => _Action(
              label: l.orderReorder,
              icon: Icons.replay_rounded,
              fg: cs.primary,
              bg: cs.primary.withValues(alpha: 0.10),
              border: cs.primary.withValues(alpha: 0.35),
              busy: busy,
              onTap: () => onAction?.call(OrderAction.reorder),
            ),
          OrderAction.none => Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
              textDirection: Directionality.of(context),
            ),
        },
      ],
    );
  }
}

/// A compact pill button, sized for a list row rather than a form.
///
/// Material's own buttons carry a 40pt minimum height and their own padding,
/// which made a card footer look like a dialog. This keeps the tap target
/// honest (36pt, inside a 48pt row) and the weight light.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.onTap,
    this.border,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color? border;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 15, color: fg),
              Gap.w6,
              Text(
                label,
                style: context.tt.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
