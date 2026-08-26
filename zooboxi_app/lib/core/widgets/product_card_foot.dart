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

/// The add control that floats on the product image, in three shapes:
///
///   ➊ the round teal "+" · ➋ an expanded stepper · ➌ a small count badge
///
/// One tap on ➊ expands to ➋ **instantly** — the server add runs behind the
/// animation, never in front of it. Left alone for a few seconds, ➋ settles
/// into ➌ so the artwork gets its corner back; tapping ➌ reopens ➋. The
/// expansion itself is the add confirmation, which is why card adds are
/// toast-silent.
///
/// Truth still belongs to the cart: the optimistic quantity only bridges the
/// round trip, and the first server answer replaces it. A failed add rolls the
/// control back to ➊.
class ProductCardAddOverlay extends ConsumerStatefulWidget {
  const ProductCardAddOverlay({
    super.key,
    required this.product,
    required this.onAdd,
  });

  final ProductCard product;

  /// Returns whether the server accepted the line. Card surfaces pass the
  /// quiet variant of the shared add path — the morph is the confirmation.
  final Future<bool> Function(ProductCard product)? onAdd;

  @override
  ConsumerState<ProductCardAddOverlay> createState() =>
      _ProductCardAddOverlayState();
}

/// The cart's view of this exact product, reduced to the values the control
/// renders. A record so `select` compares by value — a cart refresh that did
/// not touch this line must not rebuild every card in the grid.
typedef _CartLine = ({String key, int qty, int? max});

class _ProductCardAddOverlayState extends ConsumerState<ProductCardAddOverlay> {
  /// How long the stepper stays open after the last touch.
  static const _settle = Duration(milliseconds: 3500);

  /// Optimistic quantity while the first server add is in flight (no cart
  /// line exists yet to carry it). Cleared the moment the line lands.
  int? _pending;

  bool _expanded = false;
  Timer? _collapse;

  @override
  void dispose() {
    _collapse?.cancel();
    super.dispose();
  }

  void _keepOpen() {
    _collapse?.cancel();
    _collapse = Timer(_settle, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  Future<void> _firstAdd() async {
    final onAdd = widget.onAdd;
    if (onAdd == null) return;

    // A variable product can't be added blind — the customer has to pick a
    // flavour or size first, so send them to the page instead of guessing.
    if (widget.product.isVariable) {
      Haptics.light();
      unawaited(
        context.push('/product/${widget.product.id}', extra: widget.product),
      );
      return;
    }

    // Expand NOW; the network answers behind the animation.
    unawaited(Haptics.success());
    setState(() {
      _pending = 1;
      _expanded = true;
    });
    _keepOpen();

    var accepted = false;
    try {
      accepted = await onAdd(widget.product);
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    if (!accepted) {
      // The shared add path already explained why; just take the claim back.
      setState(() {
        _pending = null;
        _expanded = false;
      });
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

    // The server's line has landed — the optimistic bridge is done.
    if (line != null && _pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pending != null) setState(() => _pending = null);
      });
    }

    final qty = line?.qty ?? _pending ?? 0;

    final Widget shape;
    if (qty <= 0) {
      shape = AddButton(
        key: const ValueKey('add'),
        onTap: () => unawaited(_firstAdd()),
      );
    } else if (_expanded) {
      shape = _FloatingShell(
        key: const ValueKey('stepper'),
        child: line == null
            // Still in flight: the stepper shows, its buttons wait for the key.
            ? IgnorePointer(
                child: QtyStepper(value: qty, dense: true, onChanged: (_) {}),
              )
            : QtyStepper(
                value: line.qty,
                max: line.max,
                dense: true,
                onChanged: (value) {
                  _keepOpen();
                  ref
                      .read(cartControllerProvider.notifier)
                      .setQuantity(line.key, value);
                },
                onRemove: () {
                  _collapse?.cancel();
                  setState(() => _expanded = false);
                  unawaited(
                    ref
                        .read(cartControllerProvider.notifier)
                        .remove(line.key)
                        .catchError((_) {}),
                  );
                },
              ),
      );
    } else {
      shape = _CountBadge(
        key: const ValueKey('count'),
        count: qty,
        onTap: () {
          Haptics.light();
          setState(() => _expanded = true);
          _keepOpen();
        },
      );
    }

    // AnimatedSize slides the width between the three shapes from the same
    // corner; the switcher cross-fades the content riding inside it.
    return AnimatedSize(
      duration: context.motion(Motion.select),
      curve: Motion.emphasized,
      alignment: AlignmentDirectional.centerEnd,
      child: AnimatedSwitcher(
        duration: context.motion(Motion.select),
        switchInCurve: Motion.decelerate,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: shape,
      ),
    );
  }
}

/// A raised pill that keeps the stepper legible over any product art.
class _FloatingShell extends StatelessWidget {
  const _FloatingShell({super.key, required this.child});

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

/// The settled shape: how many are in the basket, one tap from adjusting.
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Material(
      color: cs.primary,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Text(
              count > 9 ? '9+' : '$count',
              style: context.tt.labelMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
