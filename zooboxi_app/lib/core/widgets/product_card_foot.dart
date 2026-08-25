import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../features/catalog/data/product_models.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';
import 'qty_stepper.dart';

/// The add control that floats on the product image — the round teal "+"
/// button, which becomes a compact stepper the moment the line exists in the
/// cart. Same corner, same tap target, so the customer's next tap is where
/// their last one was.
///
/// State comes from the cart itself rather than from a local flag, so a
/// quantity changed on the cart screen is reflected here, and vice versa.
class ProductCardAddOverlay extends ConsumerStatefulWidget {
  const ProductCardAddOverlay({
    super.key,
    required this.product,
    required this.onAdd,
  });

  final ProductCard product;
  final Future<void> Function(ProductCard product)? onAdd;

  @override
  ConsumerState<ProductCardAddOverlay> createState() =>
      _ProductCardAddOverlayState();
}

/// The cart's view of this exact product, reduced to the three values the
/// control renders. A record so `select` compares by value — a cart refresh
/// that did not touch this line must not rebuild every card in the grid.
typedef _CartLine = ({String key, int qty, int? max});

class _ProductCardAddOverlayState extends ConsumerState<ProductCardAddOverlay> {
  bool _busy = false;

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    if (onAdd == null || _busy) return;

    // A variable product can't be added blind — the customer has to pick a
    // flavour or size first, so send them to the page instead of guessing.
    if (widget.product.isVariable) {
      Haptics.light();
      unawaited(
        context.push('/product/${widget.product.id}', extra: widget.product),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await onAdd(widget.product);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onAdd == null) return const SizedBox.shrink();

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
    if (line != null && !widget.product.isVariable) {
      final notifier = ref.read(cartControllerProvider.notifier);
      child = _FloatingStepper(
        key: const ValueKey('stepper'),
        child: QtyStepper(
          value: line.qty,
          max: line.max,
          dense: true,
          onChanged: (value) => notifier.setQuantity(line.key, value),
          onRemove: () => unawaited(notifier.remove(line.key).catchError((_) {})),
        ),
      );
    } else {
      child = AddButton(
        key: const ValueKey('add'),
        onTap: () => unawaited(_add()),
        busy: _busy,
      );
    }

    return AnimatedSwitcher(
      duration: context.motion(Motion.select),
      switchInCurve: Motion.decelerate,
      transitionBuilder: (widget, animation) =>
          ScaleTransition(scale: animation, child: widget),
      child: child,
    );
  }
}

/// A raised pill that keeps the stepper legible over any product art.
class _FloatingStepper extends StatelessWidget {
  const _FloatingStepper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
