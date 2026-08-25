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
import 'widgets/order_sections.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_timeline.dart';

/// One order, end to end.
///
/// The timeline leads because it answers the only question anyone opens this
/// screen for — *where is it* — and the receipt follows underneath for the
/// times the question is *what did I pay*.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

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
          builder: (detail) => _Detail(detail: detail),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.detail});

  final OrderDetail detail;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final detail = widget.detail;
    final summary = detail.summary;
    final locale = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(summary: summary),
        Gap.h16,

        if (summary.awaitsPayment) ...[
          _PayNowBanner(summary: summary),
          Gap.h16,
        ],

        if (detail.timeline.isNotEmpty) ...[
          OrderSection(
            title: l.orderTimelineTitle,
            icon: Icons.route_rounded,
            child: OrderTimeline(steps: detail.timeline),
          ),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
