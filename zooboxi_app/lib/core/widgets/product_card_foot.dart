import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../features/catalog/data/product_models.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';
import 'qty_stepper.dart';

/// The add control that floats on the product image, in three shapes:
///
///   ➊ the round teal "+" · ➋ an expanded stepper · ➌ a small count badge
///
/// One container morphs between them — width, colour (teal ↔ surface),
/// border and shadow all animate as one, with a touch of overshoot on the
/// way open. The content cross-fades inside while the shell is still moving,
/// which is what makes it read as *growing* rather than *swapping*.
///
/// The control is alive from the very first frame: while the initial server
/// add is in flight the +/− already work against an optimistic quantity, and
/// the first real cart line reconciles to whatever the customer meanwhile
/// chose — including "changed my mind", which removes the line the moment it
/// lands. Truth stays with the cart; the optimism only bridges the round trip.
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

  static const double _size = 34;
  static const double _stepperWidth = 100;

  /// What the customer wants while no cart line exists yet to carry it.
  /// Null once the server's line is the source of truth.
  int? _pending;

  /// The customer closed the line (− at 1) while the add was still in
  /// flight — remove it the moment it lands instead of resurrecting it.
  bool _cancelOnLand = false;

  bool _expanded = false;
  Timer? _collapse;

  /// Overshoot on the way open, clean ease on the way closed.
  Curve _shellCurve = Curves.easeOutBack;

  @override
  void dispose() {
    _collapse?.cancel();
    super.dispose();
  }

  void _keepOpen() {
    _collapse?.cancel();
    _collapse = Timer(_settle, () {
      if (!mounted) return;
      setState(() {
        _expanded = false;
        _shellCurve = Curves.easeInOutCubic;
      });
    });
  }

  void _open() {
    _expanded = true;
    _shellCurve = Curves.easeOutBack;
    _keepOpen();
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
      _cancelOnLand = false;
      _open();
    });

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
        _cancelOnLand = false;
        _expanded = false;
        _shellCurve = Curves.easeInOutCubic;
      });
    }
  }

  /// The server's line arrived — replay whatever the customer decided while
  /// it was in flight, exactly once, after this frame.
  void _reconcile(_CartLine line) {
    final target = _pending;
    final cancel = _cancelOnLand;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_pending == null && !_cancelOnLand)) return;
      final notifier = ref.read(cartControllerProvider.notifier);
      setState(() {
        _pending = null;
        _cancelOnLand = false;
      });
      if (cancel) {
        unawaited(notifier.remove(line.key).catchError((_) {}));
      } else if (target != null && target != line.qty) {
        notifier.setQuantity(line.key, target);
      }
    });
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

    if (line != null && (_pending != null || _cancelOnLand)) _reconcile(line);

    final pendingQty = _cancelOnLand ? 0 : _pending;
    final qty = pendingQty ?? line?.qty ?? 0;
    final open = _expanded && qty > 0;

    final cs = context.cs;

    final Widget face;
    if (qty <= 0) {
      face = _RoundFace(
        key: const ValueKey('add'),
        icon: Icons.add_rounded,
        onTap: () => unawaited(_firstAdd()),
      );
    } else if (open) {
      face = SizedBox(
        key: const ValueKey('stepper'),
        width: _stepperWidth,
        child: QtyStepper(
          value: qty,
          max: line?.max,
          dense: true,
          onChanged: (value) {
            _keepOpen();
            if (line != null && _pending == null) {
              ref.read(cartControllerProvider.notifier).setQuantity(line.key, value);
            } else {
              // Still in flight — steer the optimistic number; _reconcile
              // replays the final choice when the line lands.
              setState(() => _pending = value);
            }
          },
          onRemove: () {
            _collapse?.cancel();
            if (line != null && _pending == null) {
              setState(() {
                _expanded = false;
                _shellCurve = Curves.easeInOutCubic;
              });
              unawaited(
                ref
                    .read(cartControllerProvider.notifier)
                    .remove(line.key)
                    .catchError((_) {}),
              );
            } else {
              setState(() {
                _cancelOnLand = true;
                _expanded = false;
                _shellCurve = Curves.easeInOutCubic;
              });
            }
          },
        ),
      );
    } else {
      face = _RoundFace(
        key: const ValueKey('count'),
        label: qty > 9 ? '9+' : '$qty',
        onTap: () {
          Haptics.light();
          setState(_open);
        },
      );
    }

    // One shell, three faces. Width, colour, border and shadow morph together;
    // the face cross-fades faster than the shell moves, so the contents are
    // already legible while the pill is still growing.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: _shellCurve,
      width: open ? _stepperWidth : _size,
      height: _size,
      decoration: BoxDecoration(
        color: open ? cs.surfaceContainerHigh : cs.primary,
        borderRadius: BorderRadius.circular(_size / 2),
        border: Border.all(
          color: open ? cs.outlineVariant : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: open ? 0.14 : 0.22),
            blurRadius: open ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 170)),
        switchInCurve: const Interval(0.35, 1, curve: Curves.easeOut),
        switchOutCurve: const Interval(0.65, 1, curve: Curves.easeIn),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        child: face,
      ),
    );
  }
}

/// The circular faces (+ and the count), drawn transparent so the shell
/// underneath supplies the teal — that is what lets the colour itself morph.
class _RoundFace extends StatelessWidget {
  const _RoundFace({super.key, this.icon, this.label, required this.onTap});

  final IconData? icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: cs.onPrimary)
                : Text(
                    label!,
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
