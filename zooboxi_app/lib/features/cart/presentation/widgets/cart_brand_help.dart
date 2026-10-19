import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/rail.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../brand/data/brand_activation.dart';
import '../../../brand/presentation/widgets/brand_palette.dart';
import '../../../brand/presentation/widgets/brand_shelves.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/data/product_models.dart';
import '../../data/cart_controller.dart';
import '../../data/cart_models.dart';
import '../add_to_cart.dart';

// «تفعيل البراندات» C — «لحظة القرار»: the brand where the customer decides.
// In the cart that is three things, each from the store's own facts:
//   - a line this shelf cannot send → the same line at about the same price;
//   - a pack with an honestly cheaper bigger pack → that one, in its colours;
//   - the brand that fills the basket → more of it this shelf can send.

/// Swap one cart line for another product: add the new one at the same
/// quantity, then drop the old line. The add goes first — a failed add must
/// not leave the customer with neither.
Future<bool> swapCartLine(
  BuildContext context,
  WidgetRef ref, {
  required CartItem from,
  required ProductCard to,
  int? quantity,
  required String zone,
}) async {
  if (to.isVariable) {
    // A variable product needs its option chosen on its own page.
    unawaited(context.push('/product/${to.id}', extra: to));
    return false;
  }
  Haptics.selection();
  final added = await addToCart(context, ref, product: to, quantity: quantity ?? from.qty, zone: zone, quiet: true);
  if (!added) return false;
  await ref.read(cartControllerProvider.notifier).remove(from.key);
  if (context.mounted) AppToast.success(context, L.of(context).cartSubSwapped(to.name));
  return true;
}

/// Under a line this shelf cannot send: «تشورو تونا نفد في إكسبريس» and the
/// same line's closest-priced product with one tap to swap.
class CartSubstituteRow extends ConsumerStatefulWidget {
  const CartSubstituteRow({super.key, required this.item, required this.help, required this.express});

  final CartItem item;
  final CartLineHelp help;
  final bool express;

  @override
  ConsumerState<CartSubstituteRow> createState() => _CartSubstituteRowState();
}

class _CartSubstituteRowState extends ConsumerState<CartSubstituteRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final sub = widget.help.substitute!;
    final dark = context.isDark;
    final warn = dark ? ZbTokens.coralOnDark : ZbTokens.coralDark;
    final kicker = widget.help.samePrice ? '${l.cartSubKicker} · ${l.cartSubSamePrice}' : l.cartSubKicker;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: dark ? ZbTokens.coralContainerDark : ZbTokens.coralTintSoft,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: warn.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 17, color: warn),
              Gap.w6,
              Expanded(
                child: Text(
                  widget.express ? l.cartSubOutExpress(widget.item.name) : l.cartSubOut(widget.item.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelLarge?.copyWith(color: warn, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/product/${sub.id}', extra: sub),
                child: SizedBox(width: 48, height: 48, child: ZbImage(url: sub.image, fit: BoxFit.contain)),
              ),
              Gap.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kicker,
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(
                      sub.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Gap.w8,
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await swapCartLine(context, ref, from: widget.item, to: sub, zone: 'cart_substitute');
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: context.cs.onSurface,
                  foregroundColor: context.cs.surface,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(l.cartSubSwap),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «العبوة الكبيرة أوفر» for the pack in the basket — the brand page's band in
/// the brand's colours, with a swap to the bigger pack under it.
class CartUpgradeBand extends ConsumerStatefulWidget {
  const CartUpgradeBand({super.key, required this.item, required this.value, this.brand});

  final CartItem item;
  final BrandValue value;
  final BrandSummary? brand;

  @override
  ConsumerState<CartUpgradeBand> createState() => _CartUpgradeBandState();
}

class _CartUpgradeBandState extends ConsumerState<CartUpgradeBand> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final palette = widget.brand == null
        ? BrandPalette.from(context)
        : BrandPalette.ofSummary(context, widget.brand!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandValueBand(value: widget.value, palette: palette),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      // One big pack stands in for the small one, however many of it.
                      await swapCartLine(context, ref,
                          from: widget.item, to: widget.value.product, quantity: 1, zone: 'cart_upgrade');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            style: TextButton.styleFrom(foregroundColor: palette.deep),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(l.cartUpgradeSwap, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

/// «أكمل من إينابا»: the basket's leading brand, what else of it this shelf
/// can send — its lines in the basket first.
class CartCompleteRail extends ConsumerWidget {
  const CartCompleteRail({super.key, required this.brand, required this.products});

  final BrandSummary brand;
  final List<ProductCard> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ProductRailView(
      title: l.cartCompleteTitle(brand.name),
      subtitle: l.cartCompleteSub,
      products: products,
      zone: 'cart_brand',
      edge: 0,
      onAdd: (product) => addToCart(context, ref, product: product, zone: 'cart_brand', quiet: true),
    );
  }
}
