import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/totals_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../loyalty/presentation/widgets/claim_reward_sheet.dart';
import '../data/cart_controller.dart';
import '../data/cart_models.dart';
import 'widgets/cart_line.dart';
import 'widgets/coupon_field.dart';
import 'widgets/free_shipping_bar.dart';
import 'widgets/shipment_card.dart';

/// The cart.
///
/// It renders the split shipments the fulfilment engine produced rather than
/// one flat list, because a basket sourced from three warehouses genuinely
/// arrives in three deliveries — collapsing that into one line would make the
/// promise on the product page a lie at the moment of payment.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cart = ref.watch(cartControllerProvider);

    // Notices are the server explaining what it changed (a capped quantity, a
    // dropped line). They surface once, on the screen where they make sense.
    ref.listen(cartControllerProvider, (_, _) => _drainNotices());

    return Scaffold(
      appBar: AppBar(
        title: Text(l.cartTitle),
        actions: [
          if (cart.value != null && cart.value!.count > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  l.cartItems(cart.value!.count),
                  style: context.tt.bodySmall
                      ?.copyWith(color: context.cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
      body: cart.hasValue
          ? _Loaded(cart: cart.requireValue)
          : cart.hasError
              ? ErrorState(
                  error: cart.error,
                  onRetry: () => ref.read(cartControllerProvider.notifier).refresh(),
                )
              : const _CartSkeleton(),
    );
  }

  void _drainNotices() {
    final notices = ref.read(cartControllerProvider.notifier).drainNotices();
    if (notices.isEmpty || !mounted) return;
    final notice = notices.first;
    if (notice.isError) {
      AppToast.error(context, notice.text);
    } else {
      AppToast.info(context, notice.text);
    }
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.cart});

  final CartData cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    if (cart.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_rounded,
        title: l.cartEmpty,
        message: l.cartEmptyHint,
        actionLabel: l.cartStartShopping,
        onAction: () => context.go('/home'),
        mascot: true,
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () => ref.read(cartControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (cart.freeShipping.isActive || cart.loyalty.hasDeliveryPerk) ...[
                  FreeShippingBar(
                    freeShipping: cart.freeShipping,
                    freeDeliveryReason: cart.loyalty.freeDeliveryReason,
                    expressFreeReason: cart.loyalty.expressFreeReason,
                  ),
                  Gap.h16,
                ],
                for (final item in cart.items) ...[
                  CartLineView(item: item),
                  Gap.h12,
                ],
                if (cart.shipments.length > 1) ...[
                  Gap.h8,
                  Text(l.cartShipments, style: context.tt.titleMedium),
                  Gap.h4,
                  Text(
                    l.cartShipmentsHint,
                    style: context.tt.bodySmall
                        ?.copyWith(color: context.cs.onSurfaceVariant),
                  ),
                  Gap.h12,
                  for (final shipment in cart.shipments) ...[
                    ShipmentCard(shipment: shipment),
                    Gap.h8,
                  ],
                ],
                Gap.h16,
                const _UseRewardButton(),
                CouponField(coupons: cart.coupons),
                Gap.h20,
                TotalsCard(
                  totals: cart.totals,
                  pawsToEarn: cart.loyalty.pawsToEarn,
                ),
              ],
            ),
          ),
        ),
        _CheckoutBar(total: cart.totals.total),
      ],
    );
  }
}

/// «استخدم مكافأة» — visible only when there is actually a reward to use.
///
/// It reads the grants rather than the tier, so a customer who has nothing in
/// hand is never shown a button that can only disappoint them, and a loyalty
/// outage removes the button instead of breaking the basket.
class _UseRewardButton extends ConsumerWidget {
  const _UseRewardButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAuthenticatedProvider)) return const SizedBox.shrink();
    // The summary is already in hand (kept alive for the session) and says how
    // many grants this customer holds; only when that is non-zero is the
    // catalogue worth a request. A cart with nothing to use costs no call.
    final held = ref.watch(loyaltySummaryProvider).value?.rewards.activeCount ?? 0;
    if (held <= 0) return const SizedBox.shrink();
    final grants = ref.watch(claimableGrantsProvider);
    if (grants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () => showClaimRewardSheet(context),
        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
        label: Text(L.of(context).rewardUseButton),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          foregroundColor: context.cs.primary,
          side: BorderSide(color: context.cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

/// The one door into checkout.
///
/// Sign-in is asked for *here* rather than inside the flow, because the web
/// store gates guests the same way and because discovering you need an account
/// three steps in — with an address half typed — is the worst place to learn it.
class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({required this.total});

  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(
            onPressed: () => _startCheckout(context, ref),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.cartCheckout),
                Gap.w8,
                Container(width: 1, height: 16, color: cs.onPrimary.withValues(alpha: 0.32)),
                Gap.w8,
                Text(Fmt.price(total, locale: locale)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckout(BuildContext context, WidgetRef ref) async {
    Haptics.light();
    if (!ref.read(sessionProvider).isAuthenticated) {
      final signedIn =
          await showAuthSheet(context, reason: L.of(context).checkoutSignInReason);
      if (!signedIn || !context.mounted) return;
    }
    await context.push<void>('/checkout');
  }
}

class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          // Nothing pins the bottom while the cart is still loading, so the
          // list clears the floating tab bar itself.
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            const SkeletonBox(width: double.infinity, height: 54, radius: ZbTokens.rMd),
            Gap.h16,
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(width: double.infinity, height: 104, radius: ZbTokens.rLg),
              Gap.h12,
            ],
            Gap.h8,
            const SkeletonBox(width: double.infinity, height: 150, radius: ZbTokens.rLg),
          ],
        ),
      );
}
