import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';
import 'product_card_metrics.dart';
import 'qty_stepper.dart';

/// The one control at the bottom of a product card.
///
/// It has exactly one job and shows exactly one state: add it, choose a
/// variant, adjust what is already in the basket, or say it is sold out. The
/// pill *becomes* the stepper the moment the line exists in the cart — the
/// same real estate, so the card never reflows and the customer's next tap is
/// where their last one was.
///
/// State comes from the cart itself rather than from a local flag, so a
/// quantity changed on the cart screen is reflected here, and vice versa.
class ProductCardFoot extends ConsumerStatefulWidget {
  const ProductCardFoot({
    super.key,
    required this.product,
    required this.onAdd,
    required this.outOfStock,
  });

  final ProductCard product;
  final Future<void> Function(ProductCard product)? onAdd;
  final bool outOfStock;

  @override
  ConsumerState<ProductCardFoot> createState() => _ProductCardFootState();
}

/// The cart's view of this exact product, reduced to the three values the foot
/// renders. A record so `select` compares by value — a cart refresh that did
/// not touch this line must not rebuild every card in the grid.
typedef _CartLine = ({String key, int qty, int? max});

class _ProductCardFootState extends ConsumerState<ProductCardFoot> {
  bool _busy = false;

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    if (onAdd == null || _busy) return;

    // A variable product can't be added blind — the customer has to pick a
    // flavour or size first, so send them to the page instead of guessing.
    if (widget.product.isVariable) {
      _openProduct();
      return;
    }

    setState(() => _busy = true);
    try {
      await onAdd(widget.product);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openProduct() {
    Haptics.light();
    unawaited(
      context.push('/product/${widget.product.id}', extra: widget.product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final height = ProductCardMetrics.footSlot(context);

    final line = ref.watch(
      cartControllerProvider.select<_CartLine?>((state) {
        final item = state.value?.items
            .where((i) => i.productId == widget.product.id && i.variationId == null)
            .firstOrNull;
        return item == null
            ? null
            : (key: item.key, qty: item.qty, max: item.maxReachable);
      }),
    );

    final Widget child;
    if (widget.onAdd == null) {
      // No add action was supplied for this surface; the slot stays reserved
      // so the card still ends where its neighbours do.
      child = const SizedBox.shrink();
    } else if (widget.outOfStock) {
      child = _Pill(label: l.cardOutOfStock, onTap: null);
    } else if (widget.product.isVariable) {
      child = _Pill(
        label: l.cardChooseOptions,
        icon: Icons.tune_rounded,
        onTap: _openProduct,
      );
    } else if (line != null) {
      final notifier = ref.read(cartControllerProvider.notifier);
      child = QtyStepper(
        key: const ValueKey('stepper'),
        value: line.qty,
        max: line.max,
        dense: true,
        stretch: true,
        onChanged: (value) => notifier.setQuantity(line.key, value),
        onRemove: () => unawaited(notifier.remove(line.key).catchError((_) {})),
      );
    } else {
      child = _Pill(
        key: const ValueKey('add'),
        label: l.cardAdd,
        icon: Icons.add_rounded,
        busy: _busy,
        onTap: _add,
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: context.motion(Motion.select),
        switchInCurve: Motion.decelerate,
        // The default layout hands its children *loose* constraints, which
        // would let the pill shrink to its label and stop matching the
        // stepper it swaps with. Expanding the stack keeps both controls on
        // exactly the same footprint, which is the point of the morph.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          alignment: AlignmentDirectional.center,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}

/// Full-width tonal pill. Teal, flat, and the same height as the stepper it
/// swaps with.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return FilledButton.tonal(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        disabledBackgroundColor: cs.surfaceContainerHighest,
        disabledForegroundColor: cs.onSurfaceVariant,
        textStyle: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        // The slot owns the height; anything the button adds on top of it —
        // Material's 48pt tap padding especially — would overflow it.
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
        ),
        elevation: 0,
      ),
      child: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimaryContainer,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  Gap.w4,
                ],
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
    );
  }
}
