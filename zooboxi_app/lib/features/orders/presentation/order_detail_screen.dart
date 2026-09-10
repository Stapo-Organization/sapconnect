import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/totals_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';
import '../../checkout/data/checkout_models.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';
import 'widgets/live_tracking_card.dart';
import 'widgets/order_sections.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_timeline.dart';

/// One order, end to end.
///
/// The timeline leads because it answers the only question anyone opens this
/// screen for — *where is it* — and the receipt follows underneath for the
/// times the question is *what did I pay*.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.rate = false});

  final int orderId;

  /// Arrived from «قيّم توصيلتك» — the notification that asks for the rating
  /// deep-links here with `?rate=1`, and the card it means is brought into
  /// view instead of being left below three sections of receipt.
  final bool rate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final order = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l.orderDetailTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(orderDetailProvider(orderId));
          await ref.read(orderDetailProvider(orderId).future);
        },
        child: AsyncView<OrderDetail>(
          value: order,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
          skeleton: const _DetailSkeleton(),
          builder: (detail) => _Detail(detail: detail, rate: rate),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.detail, this.rate = false});

  final OrderDetail detail;
  final bool rate;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _reordering = false;

  /// Where the rating card sits, so a `?rate=1` arrival can scroll to it.
  final GlobalKey _rateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.rate) return;
    // After the first frame: the card has no position until the list has been
    // laid out, and an order that turns out to be rated already has no card
    // at all — in which case this quietly does nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _rateKey.currentContext;
      if (target == null) return;
      unawaited(Scrollable.ensureVisible(
        target,
        alignment: 0.12,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final detail = widget.detail;
    final summary = detail.summary;
    final locale = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(summary: summary),
        Gap.h16,

        if (summary.awaitsPayment) ...[
          _PayNowBanner(summary: summary),
          Gap.h16,
        ],

        // The courier leads everything else. Once someone is carrying the box
        // toward your door, "where is it" has exactly one answer and it is not
        // the preparation timeline.
        _LiveTracking(orderId: summary.id),

        if (detail.timeline.isNotEmpty) ...[
          OrderSection(
            title: l.orderTimelineTitle,
            icon: Icons.route_rounded,
            child: OrderTimeline(steps: detail.timeline),
          ),
          Gap.h12,
        ],

        // The verdict comes straight after the timeline: it is the last step
        // of that story, and it is asked only once the box has landed.
        if (summary.status == 'completed') ...[
          if (summary.rating == null)
            _RateCard(key: _rateKey, orderId: summary.id)
          else
            _RatingGiven(key: _rateKey, rating: summary.rating!),
          Gap.h12,
        ],

        if (detail.tracking != null) ...[
          OrderSection(
            title: l.orderTrackingTitle,
            icon: Icons.local_shipping_outlined,
            child: OrderTrackingBlock(tracking: detail.tracking!),
          ),
          Gap.h12,
        ],

        if (detail.items.isNotEmpty) ...[
          OrderSection(
            title: l.orderItemsTitle,
            icon: Icons.shopping_bag_outlined,
            trailing: Text(
              l.cartItems(summary.itemsCount),
              style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            child: OrderItemsList(items: detail.items),
          ),
          Gap.h12,
        ],

        if (detail.address != null) ...[
          OrderSection(
            title: l.orderAddressTitle,
            icon: Icons.place_outlined,
            child: OrderAddressBlock(address: detail.address!),
          ),
          Gap.h12,
        ],

        if ((detail.notes ?? '').isNotEmpty) ...[
          OrderSection(
            title: l.orderNotesTitle,
            icon: Icons.sticky_note_2_outlined,
            child: Text(detail.notes!, style: context.tt.bodyMedium),
          ),
          Gap.h12,
        ],

        OrderSection(
          title: l.orderPaymentMethod,
          icon: Icons.receipt_long_outlined,
          trailing: Text(
            summary.paymentMethod == 'cod' ? l.orderPaymentCod : l.orderPaymentOnline,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          child: TotalsCard(
            totals: detail.totals,
            bordered: false,
            padding: EdgeInsets.zero,
          ),
        ),

        if (summary.canReorder) ...[
          Gap.h20,
          FilledButton.icon(
            onPressed: _reordering ? null : _reorder,
            icon: _reordering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.replay_rounded, size: 20),
            label: Text(l.orderReorder),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ],

        if (summary.date != null) ...[
          Gap.h16,
          Center(
            child: Text(
              Fmt.dateTime(summary.date!, locale),
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }

  /// Refills the cart from this order. The result is stated honestly — "3
  /// added, 1 unavailable" — because silently dropping a line is how someone
  /// discovers at the door that half the order is missing.
  Future<void> _reorder() async {
    final l = L.of(context);
    setState(() => _reordering = true);
    try {
      final result =
          await ref.read(ordersRepositoryProvider).reorder(widget.detail.summary.id);
      ref.read(cartControllerProvider.notifier).applyServerCart(result.cart);
      if (!mounted) return;
      await Haptics.success();
      if (!mounted) return;

      setState(() => _reordering = false);
      if (result.missing.isEmpty) {
        AppToast.success(context, l.orderReorderAdded(result.added));
      } else {
        AppToast.info(
          context,
          '${l.orderReorderAdded(result.added)} · '
          '${l.orderReorderMissing(result.missing.length)}',
        );
      }
      context.go('/cart');
    } catch (e) {
      if (!mounted) return;
      setState(() => _reordering = false);
      Haptics.warning();
      AppToast.error(context, errorMessage(context, e));
    }
  }
}

/// «كيف كانت توصيلتك؟» — five stars, and only then a place to say more.
///
/// The comment field stays hidden until a star is tapped, because a text box
/// under a question makes the whole thing look like a form. One tap is a
/// complete answer here; the note is for the customer who wants to add one.
class _RateCard extends ConsumerStatefulWidget {
  const _RateCard({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends ConsumerState<_RateCard> {
  final TextEditingController _comment = TextEditingController();
  int _stars = 0;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = L.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(ordersRepositoryProvider).rate(
            widget.orderId,
            stars: _stars,
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      // The card is replaced by the store's own copy of what was said, so
      // nothing on screen is the app's guess at what was saved.
      ref.invalidate(orderDetailProvider(widget.orderId));
      await Haptics.success();
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.success(context, l.orderRateThanks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      Haptics.warning();
      AppToast.error(context, errorMessage(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return OrderSection(
      title: l.orderRateTitle,
      icon: Icons.star_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stars(
            stars: _stars,
            size: 38,
            onTap: _sending
                ? null
                : (value) {
                    Haptics.selection();
                    setState(() => _stars = value);
                  },
          ),
          if (_stars > 0) ...[
            Gap.h12,
            TextField(
              controller: _comment,
              enabled: !_sending,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_sending) unawaited(_submit());
              },
              decoration: InputDecoration(
                hintText: l.orderRateComment,
                isDense: true,
              ),
            ),
            Gap.h12,
            FilledButton(
              onPressed: _sending ? null : () => unawaited(_submit()),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l.orderRateSubmit),
            ),
          ] else ...[
            Gap.h8,
            Text(
              l.orderRateHint,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// «تقييمك ★★★★☆» — one line, because the question has been answered and the
/// screen is back to being about the order.
class _RatingGiven extends StatelessWidget {
  const _RatingGiven({super.key, required this.rating});

  final OrderRating rating;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.orderRateYours, style: context.tt.titleSmall)),
              _Stars(stars: rating.stars, size: 18),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            Gap.h4,
            Text(
              rating.comment,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Five stars. Tappable when [onTap] is given, a read-out when it is not —
/// the same row either way, so a rating never changes shape once it is made.
class _Stars extends StatelessWidget {
  const _Stars({required this.stars, required this.size, this.onTap});

  final int stars;
  final double size;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    final cs = context.cs;
    return Row(
      mainAxisSize: onTap == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          onTap == null ? MainAxisAlignment.end : MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 1; i <= 5; i++)
          if (onTap == null)
            Icon(
              i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= stars ? zb.warning : cs.outlineVariant,
            )
          else
            IconButton(
              onPressed: () => onTap!(i),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
              icon: Icon(
                i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= stars ? zb.warning : cs.outlineVariant,
              ),
            ),
      ],
    );
  }
}

/// The live courier panel, or nothing at all.
///
/// Deliberately its own consumer: the courier's position refreshes every ten
/// seconds and the rest of the order does not, so only this subtree rebuilds.
/// While it is loading — or once the poll has decided this order has no courier
/// — it occupies no space, which is the right answer for every order that was
/// not delivered by one.
class _LiveTracking extends ConsumerWidget {
  const _LiveTracking({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(liveTrackingProvider(orderId)).value;
    if (tracking == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiveTrackingCard(tracking: tracking, orderId: orderId),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final OrderSummary summary;

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
              Text(
                '#${summary.number}',
                textDirection: TextDirection.ltr,
                style: context.tt.headlineSmall,
              ),
              Gap.h4,
              Text(
                Fmt.price(summary.total, locale: locale),
                style: context.tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        OrderStatusPill(order: summary),
      ],
    );
  }
}

/// An unpaid online order is the one state the customer can still act on.
class _PayNowBanner extends StatelessWidget {
  const _PayNowBanner({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final zb = context.zb;

    return Container(
      decoration: BoxDecoration(
        color: zb.warning.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: zb.warning.withValues(alpha: 0.42)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: zb.warning),
          Gap.w12,
          Expanded(
            child: Text(l.orderUnpaid, style: context.tt.bodyMedium),
          ),
          FilledButton(
            onPressed: () {
              Haptics.light();
              // Replace, not push: leaving the payment screen returns here,
              // and two stacked copies of the same order is not a back stack.
              context.pushReplacement(
                '/checkout/pay',
                extra: PlacedOrder(
                  orderId: summary.id,
                  orderNumber: summary.number,
                  orderKey: summary.orderKey,
                  status: summary.status,
                  total: summary.total,
                  paymentMethod: summary.paymentMethod ?? 'myfatoorah',
                  paymentRequired: true,
                ),
              );
            },
            child: Text(l.orderPayNow),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const SkeletonBox(width: 150, height: 28, radius: ZbTokens.rXs),
            Gap.h20,
            const SkeletonBox(width: double.infinity, height: 210, radius: ZbTokens.rLg),
            Gap.h12,
            const SkeletonBox(width: double.infinity, height: 150, radius: ZbTokens.rLg),
            Gap.h12,
            const SkeletonBox(width: double.infinity, height: 120, radius: ZbTokens.rLg),
          ],
        ),
      );
}
