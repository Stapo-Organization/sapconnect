import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
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
                if (cart.freeShipping.isActive) ...[
                  FreeShippingBar(freeShipping: cart.freeShipping),
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
                CouponField(coupons: cart.coupons),
                Gap.h20,
                _Totals(totals: cart.totals, coupons: cart.coupons),
              ],
            ),
          ),
        ),
        _CheckoutBar(total: cart.totals.total),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.coupons});

  final CartTotals totals;
  final List<CartCoupon> coupons;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _row(context, l.cartSubtotal, Fmt.price(totals.subtotal, locale: locale)),
          if (totals.discount > 0)
            _row(
              context,
              l.cartDiscount,
              '-${Fmt.price(totals.discount, locale: locale)}',
              highlight: context.zb.sale,
            ),
          _row(
            context,
            l.cartShipping,
            totals.shipping <= 0 ? l.cartFree : Fmt.price(totals.shipping, locale: locale),
            highlight: totals.shipping <= 0 ? context.zb.success : null,
          ),
          if (totals.tax > 0)
            _row(context, l.cartTax, Fmt.price(totals.tax, locale: locale)),
          Divider(height: 20, color: cs.outlineVariant),
          _row(
            context,
            l.cartTotal,
            Fmt.price(totals.total, locale: locale),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? highlight,
  }) {
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

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              Haptics.light();
              context.push('/checkout');
            },
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
}

class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
