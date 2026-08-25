import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/zb_image.dart';
import '../../../l10n/app_localizations.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';

/// Order history.
///
/// Phase-1 scope: the list is real (it reads `GET /orders`), the detail screen
/// with the fulfilment timeline and tracking is the next drop. Rows are
/// therefore not tappable yet rather than tapping into a blank page.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.ordersTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(ordersProvider);
          await ref.read(ordersProvider.future);
        },
        child: AsyncView<OrdersPage>(
          value: orders,
          onRetry: () => ref.invalidate(ordersProvider),
          skeleton: const _OrdersSkeleton(),
          builder: (page) {
            if (page.orders.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_rounded,
                title: l.ordersEmpty,
                message: l.ordersEmptyHint,
                actionLabel: l.cartStartShopping,
                onAction: () => context.go('/home'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: page.orders.length,
              separatorBuilder: (_, _) => Gap.h12,
              itemBuilder: (context, index) => _OrderCard(order: page.orders[index]),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.number}',
                  style: context.tt.titleSmall,
                  textDirection: TextDirection.ltr,
                ),
              ),
              if (order.statusLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.isPaid
                        ? zb.success.withValues(alpha: 0.13)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.statusLabel!,
                    style: context.tt.labelSmall?.copyWith(
                      color: order.isPaid ? zb.success : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (order.date != null) ...[
            Gap.h4,
            Text(
              Fmt.dateFull(order.date!, locale),
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (order.itemsPreview.isNotEmpty) ...[
            Gap.h12,
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: order.itemsPreview.length,
                separatorBuilder: (_, _) => Gap.w8,
                itemBuilder: (context, index) => SizedBox(
                  width: 48,
                  child: ZbImage(
                    url: order.itemsPreview[index].image,
                    radius: BorderRadius.circular(ZbTokens.rXs),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ),
            ),
          ],
          Gap.h12,
          Divider(height: 1, color: cs.outlineVariant),
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: Text(
                  L.of(context).cartTotal,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Text(
                Fmt.price(order.total, locale: locale),
                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, _) => Gap.h12,
          itemBuilder: (_, _) => const SkeletonBox(
            width: double.infinity,
            height: 168,
            radius: ZbTokens.rLg,
          ),
        ),
      );
}
