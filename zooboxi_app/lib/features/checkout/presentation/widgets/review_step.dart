import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/totals_card.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/account_models.dart';
import '../../../cart/data/cart_models.dart';
import '../../../cart/presentation/widgets/coupon_field.dart';
import '../../../cart/presentation/widgets/free_shipping_bar.dart';
import '../../../cart/presentation/widgets/shipment_card.dart';
import '../../data/checkout_models.dart';
import 'promise_recap.dart';

/// Step two: everything the customer is agreeing to, on one screen.
///
/// The item list starts collapsed. By this point they have already seen the
/// basket; what changes at checkout is the *fulfilment* — which shipment,
/// which date, which fee — so that gets the space and the items stay one tap
/// away for anyone who wants to double-check.
class CheckoutReviewStep extends StatefulWidget {
  const CheckoutReviewStep({
    super.key,
    required this.review,
    required this.address,
    required this.onChangeAddress,
    this.changedNotice,
  });

  final CheckoutReview review;
  final Address? address;
  final VoidCallback onChangeAddress;

  /// Shown when the server re-priced the basket at this address and something
  /// moved — the customer must see it before paying.
  final String? changedNotice;

  @override
  State<CheckoutReviewStep> createState() => _CheckoutReviewStepState();
}

class _CheckoutReviewStepState extends State<CheckoutReviewStep> {
  bool _itemsOpen = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final review = widget.review;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (widget.changedNotice != null) ...[
          _ChangedBanner(message: widget.changedNotice!),
          Gap.h16,
        ],

        if (widget.address != null) ...[
          _DeliverToCard(address: widget.address!, onChange: widget.onChangeAddress),
          Gap.h16,
        ],

        if (review.freeShipping.isActive) ...[
          FreeShippingBar(freeShipping: review.freeShipping),
          Gap.h16,
        ],

        if (!review.promise.isEmpty) ...[
          PromiseRecap(promise: review.promise),
          Gap.h16,
        ],

        if (review.shipments.isNotEmpty) ...[
          Text(l.cartShipments, style: context.tt.titleMedium),
          Gap.h4,
          Text(
            l.cartShipmentsHint,
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
          ),
          Gap.h12,
          for (final shipment in review.shipments) ...[
            ShipmentCard(shipment: shipment),
            Gap.h8,
          ],
          Gap.h8,
        ],

        _ItemsSummary(
          items: review.items,
          open: _itemsOpen,
          onToggle: () => setState(() => _itemsOpen = !_itemsOpen),
        ),
        Gap.h16,

        CouponField(coupons: review.coupons),
        Gap.h20,

        TotalsCard(totals: review.totals),
      ],
    );
  }
}

class _ChangedBanner extends StatelessWidget {
  const _ChangedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final zb = context.zb;

    return Container(
      decoration: BoxDecoration(
        color: zb.warning.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: zb.warning.withValues(alpha: 0.42)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: zb.warning),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.checkoutCartChangedTitle,
                  style: context.tt.titleSmall?.copyWith(color: zb.warning),
                ),
                Gap.h4,
                Text(message, style: context.tt.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverToCard extends StatelessWidget {
  const _DeliverToCard({required this.address, required this.onChange});

  final Address address;
  final VoidCallback onChange;

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
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_rounded, size: 18, color: cs.primary),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.checkoutDeliverTo,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Gap.h4,
                Text(
                  address.name,
                  style: context.tt.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [address.addressLine, address.summary]
                      .where((e) => e.isNotEmpty)
                      .join('، '),
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l.checkoutChangeAddress)),
        ],
      ),
    );
  }
}

class _ItemsSummary extends StatelessWidget {
  const _ItemsSummary({
    required this.items,
    required this.open,
    required this.onToggle,
  });

  final List<CartItem> items;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final count = items.fold<int>(0, (sum, item) => sum + item.qty);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 18, color: cs.onSurfaceVariant),
                  Gap.w12,
                  Expanded(
                    child: Text(l.cartItems(count), style: context.tt.titleSmall),
                  ),
                  Text(
                    open ? l.checkoutItemsHide : l.checkoutItemsShow,
                    style: context.tt.labelMedium?.copyWith(color: cs.primary),
                  ),
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: ZbImage(
                              url: item.image,
                              radius: BorderRadius.circular(ZbTokens.rXs),
                              padding: const EdgeInsets.all(3),
                            ),
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.bodySmall,
                            ),
                          ),
                          Gap.w8,
                          Text(
                            '×${item.qty}',
                            style: context.tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          Gap.w12,
                          Text(
                            Fmt.price(item.lineTotal, locale: locale),
                            style: context.tt.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
