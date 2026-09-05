import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/loyalty_art.dart';
import 'widgets/supply_card.dart';

/// «مخزون البيت» — every consumable the family goes through, soonest first.
///
/// This is the program's thesis as a screen: the app knows when the food runs
/// out and makes reordering one tap. The three corrections (order, ran out,
/// still enough) are the customer teaching the forecast, so each of them
/// answers with the server's fresh line rather than a local guess.
class SupplyScreen extends ConsumerStatefulWidget {
  const SupplyScreen({super.key});

  @override
  ConsumerState<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends ConsumerState<SupplyScreen> {
  int? _busyProduct;

  Future<void> _order(SupplyItem item) async {
    if (_busyProduct != null) return;
    ref.track(ZbEvent(
      type: ZbEvents.supplyAction,
      zone: 'supply',
      payload: {'product_id': item.product.id, 'action': 'order'},
    ));
    if (item.product.isVariable && item.variationId <= 0) {
      Haptics.light();
      await context.push<void>('/product/${item.product.id}', extra: item.product);
      return;
    }
    setState(() => _busyProduct = item.product.id);
    final added = await addToCart(
      context,
      ref,
      product: item.product,
      variationId: item.variationId > 0 ? item.variationId : null,
      quantity: item.qtyLast,
      zone: 'supply',
    );
    if (!mounted) return;
    setState(() => _busyProduct = null);
    if (added) unawaited(context.push('/cart'));
  }

  Future<void> _out(SupplyItem item) async {
    await _correct(item, 'out', () => ref.read(loyaltyRepositoryProvider).markOut(item.product.id, variationId: item.variationId));
  }

  Future<void> _snooze(SupplyItem item) async {
    await _correct(item, 'snooze', () => ref.read(loyaltyRepositoryProvider).snooze(item.product.id, variationId: item.variationId));
  }

  Future<void> _correct(SupplyItem item, String action, Future<SupplyItem> Function() call) async {
    if (_busyProduct != null) return;
    final l = L.of(context);
    setState(() => _busyProduct = item.product.id);
    try {
      await call();
      ref.track(ZbEvent(
        type: ZbEvents.supplyAction,
        zone: 'supply',
        payload: {'product_id': item.product.id, 'action': action},
      ));
      if (!mounted) return;
      Haptics.selection();
      AppToast.success(context, action == 'out' ? l.supplyMarkedOut : l.supplySnoozed(7));
      ref.invalidate(supplyProvider);
      ref.invalidate(loyaltySummaryProvider);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busyProduct = null);
    }
  }

  Future<void> _subscribe(SupplyItem item) async {
    if (_busyProduct != null) return;
    final l = L.of(context);
    setState(() => _busyProduct = item.product.id);
    try {
      await ref.read(loyaltyRepositoryProvider).subscribe(
            productId: item.product.id,
            variationId: item.variationId,
            qty: item.qtyLast,
            petId: item.pet?.id,
          );
      ref.track(ZbEvent(
        type: ZbEvents.supplyAction,
        zone: 'supply',
        payload: {'product_id': item.product.id, 'action': 'subscribe'},
      ));
      if (!mounted) return;
      unawaited(Haptics.success());
      AppToast.success(context, l.subsCreated);
      invalidateLoyalty(ref);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busyProduct = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final supply = ref.watch(supplyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.supplyTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(supplyProvider);
          await ref.read(supplyProvider.future);
        },
        child: AsyncView<SupplyBlock>(
          value: supply,
          onRetry: () => ref.invalidate(supplyProvider),
          skeleton: const _Skeleton(),
          builder: (block) {
            if (block.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Gap.h32,
                  EmptyState(
                    icon: Icons.restaurant_rounded,
                    title: l.supplyEmptyTitle,
                    message: l.supplyEmptyBody,
                    actionLabel: l.navHome,
                    onAction: () => context.go('/home'),
                    mascot: true,
                  ),
                ],
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZbTokens.amber.withValues(alpha: context.isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(ZbTokens.rLg),
                  ),
                  child: Row(
                    children: [
                      const PawCoin(size: 30),
                      Gap.w12,
                      Expanded(
                        child: Text(
                          l.supplyWindowHint(block.windowBefore, block.windowAfter, block.onTimePct),
                          style: context.tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.h12,
                for (final item in block.items) ...[
                  SupplyGaugeCard(
                    item: item,
                    onTimePct: block.onTimePct,
                    busy: _busyProduct == item.product.id,
                    onOrder: () => _order(item),
                    onOut: () => _out(item),
                    onSnooze: () => _snooze(item),
                    onSubscribe: () => _subscribe(item),
                  ),
                  Gap.h12,
                ],
                Gap.h8,
                Center(
                  child: Text(
                    l.supplySubtitle,
                    textAlign: TextAlign.center,
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: const [
            SkeletonBox(height: 56, radius: 16),
            Gap.h12,
            SkeletonBox(height: 150, radius: 20),
            Gap.h12,
            SkeletonBox(height: 150, radius: 20),
            Gap.h12,
            SkeletonBox(height: 150, radius: 20),
          ],
        ),
      );
}
