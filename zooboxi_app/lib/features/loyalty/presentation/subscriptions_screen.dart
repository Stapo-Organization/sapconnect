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
import '../../cart/data/cart_controller.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/loyalty_art.dart';
import 'widgets/subscription_card.dart';

/// «اشتراكاتي» — the soft subscriptions, soonest delivery first.
///
/// Nothing here charges a card. A subscription is a date the store keeps for
/// the customer, and this screen is where they move it, skip it, or turn it
/// into a basket with one tap.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  int? _busy;

  void _event(int id, String action) => ref.track(ZbEvent(
        type: ZbEvents.subscription,
        zone: 'subscriptions',
        payload: {'subscription_id': id, 'action': action},
      ));

  Future<void> _run(int id, String action, Future<void> Function() call, {String? toast}) async {
    if (_busy != null) return;
    setState(() => _busy = id);
    try {
      await call();
      _event(id, action);
      if (!mounted) return;
      Haptics.selection();
      if (toast != null) AppToast.success(context, toast);
      invalidateLoyalty(ref);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _orderNow(Subscription sub) async {
    if (_busy != null) return;
    final l = L.of(context);
    setState(() => _busy = sub.id);
    try {
      final result = await ref.read(loyaltyRepositoryProvider).orderNow(sub.id);
      ref.read(cartControllerProvider.notifier).applyServerCart(result.cart);
      _event(sub.id, 'order');
      if (!mounted) return;
      unawaited(Haptics.success());
      AppToast.success(context, l.subsBasketReady);
      unawaited(context.push('/cart'));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _edit(Subscription sub) async {
    final l = L.of(context);
    final edit = await showSubscriptionEditor(context, sub: sub);
    if (edit == null || !mounted) return;
    final repo = ref.read(loyaltyRepositoryProvider);
    if (edit.cancel) {
      await _run(sub.id, 'cancel', () => repo.cancelSubscription(sub.id), toast: l.subsCancelled);
      return;
    }
    if (edit.state != null) {
      await _run(sub.id, edit.state!, () => repo.updateSubscription(sub.id, state: edit.state));
      return;
    }
    await _run(
      sub.id,
      'edit',
      () => repo.updateSubscription(
        sub.id,
        qty: edit.qty,
        intervalDays: edit.intervalDays,
        nextAt: edit.nextAt == null ? null : _isoDate(edit.nextAt!),
      ),
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final subs = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.subsTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(subscriptionsProvider);
          await ref.read(subscriptionsProvider.future);
        },
        child: AsyncView<SubscriptionsPayload>(
          value: subs,
          onRetry: () => ref.invalidate(subscriptionsProvider),
          skeleton: const _Skeleton(),
          builder: (payload) {
            final items = payload.items.where((s) => s.state != 'cancelled').toList();
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Gap.h32,
                  EmptyState(
                    icon: Icons.autorenew_rounded,
                    title: l.subsEmptyTitle,
                    message: l.subsEmptyBody,
                    actionLabel: l.supplyTitle,
                    onAction: () => context.push('/family/supply'),
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
                    color: ZbTokens.logoTeal.withValues(alpha: context.isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(ZbTokens.rLg),
                  ),
                  child: Row(
                    children: [
                      const FamilyMarkIcon(FamilyMark.repeat, size: 30),
                      Gap.w12,
                      Expanded(
                        child: Text(
                          l.subsPerks(payload.bonusPct, payload.giftEvery),
                          style: context.tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.h12,
                for (final sub in items) ...[
                  SubscriptionCard(
                    sub: sub,
                    busy: _busy == sub.id,
                    onOrderNow: () => _orderNow(sub),
                    onSkip: () => _run(sub.id, 'skip', () => ref.read(loyaltyRepositoryProvider).skipSubscription(sub.id), toast: l.subsSkipped),
                    onEdit: () => _edit(sub),
                  ),
                  Gap.h12,
                ],
                Gap.h8,
                Center(
                  child: Text(
                    l.subsSubtitle,
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
            SkeletonBox(height: 160, radius: 20),
            Gap.h12,
            SkeletonBox(height: 160, radius: 20),
          ],
        ),
      );
}
