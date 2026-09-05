import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/cart/data/cart_controller.dart';
import '../../features/catalog/data/product_models.dart';
import '../icons/zb_icons.dart';
import '../motion/fly_to_cart.dart';
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
/// [direct] is true when the product sits in the cart as its one simple line —
/// the only case the card's inline stepper can operate on. A variable product
/// (units, flavours) may carry several variation lines: the bubble shows their
/// SUM, and quantity edits belong to the product page.
typedef _CartLine = ({String key, int qty, int? max, bool direct});

class _ProductCardAddOverlayState extends ConsumerState<ProductCardAddOverlay> {
  /// How long the stepper stays open after the last touch.
  static const _settle = Duration(milliseconds: 3500);

  static const double _size = 36;
  static const double _stepperWidth = 104;

  /// What the customer wants while no cart line exists yet to carry it.
  /// Null once the server's line is the source of truth.
  int? _pending;

  /// The customer closed the line (− at 1) while the add was still in
  /// flight — remove it the moment it lands instead of resurrecting it.
  bool _cancelOnLand = false;

  bool _expanded = false;
  Timer? _collapse;

  /// The control's own box, so the thrown thumbnail starts exactly where the
  /// finger was rather than at the card's corner.
  final GlobalKey _shellKey = GlobalKey();

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

    // Captured before the shell morphs into a stepper — after the await the
    // control is a different size in a different place.
    final from = _shellRect();

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
    if (accepted) {
      // The add already updated the cart synchronously. Whether it left a
      // live line for THIS product decides what the optimism does next.
      final hasLine = ref.read(cartControllerProvider).value?.items.any(
                (i) => i.productId == widget.product.id &&
                    i.variationId == null &&
                    i.qty > 0,
              ) ??
          false;
      if (!hasLine) {
        // A 200 that left no line — an unreachable trim, or a clamp that took
        // it straight back out. The pending 1 would bridge to nothing and
        // sit on the card as a ghost count forever; drop it.
        setState(() {
          _pending = null;
          _cancelOnLand = false;
          _expanded = false;
          _shellCurve = Curves.easeInOutCubic;
        });
      } else if (_pending == 1 && !_cancelOnLand) {
        // The line is real and the customer didn't re-tap mid-flight: hand the
        // count to the cart so a LATER removal can't be masked by a stale 1.
        setState(() => _pending = null);
      }
      if (from != null) {
        flyToCart(
          context,
          from: from,
          image: productThumbnail(widget.product.image),
        );
      }
    } else {
      // The shared add path already explained why; just take the claim back.
      setState(() {
        _pending = null;
        _cancelOnLand = false;
        _expanded = false;
        _shellCurve = Curves.easeInOutCubic;
      });
    }
  }

  Rect? _shellRect() {
    final box = _shellKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
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
      // Replays only steer a single simple line; an aggregate of variation
      // lines has no one key to write to.
      if (!line.direct) return;
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
        // Every line of this product, variations included: a كرتون added on
        // the product page must still light this card's count.
        final items = state.value?.items
                .where((i) => i.productId == widget.product.id)
                .toList() ??
            const [];
        if (items.isEmpty) return null;
        final direct = items.length == 1 && items.first.variationId == null;
        var qty = 0;
        for (final item in items) {
          qty += item.qty;
        }
        return (
          key: items.first.key,
          qty: qty,
          max: direct ? items.first.maxReachable : null,
          direct: direct,
        );
      }),
    );

    if (line != null && (_pending != null || _cancelOnLand)) _reconcile(line);

    final pendingQty = _cancelOnLand ? 0 : _pending;
    final qty = pendingQty ?? line?.qty ?? 0;
    final open = _expanded && qty > 0;

    final cs = context.cs;

    final Widget face;
    if (!open) {
      // One face for both closed states: the bag never re-animates, only its
      // little bubble flips from "+" to the count. That is the owner's ask —
      // the plus *becomes* the number, on a control that clearly means "cart".
      face = _BagFace(
        key: const ValueKey('bag'),
        count: qty,
        onTap: qty <= 0
            ? () => unawaited(_firstAdd())
            : () {
                Haptics.light();
                if (line != null && !line.direct) {
                  // Several variation lines share this count — the inline
                  // stepper has no single line to steer, the page does.
                  unawaited(context.push(
                    '/product/${widget.product.id}',
                    extra: widget.product,
                  ));
                  return;
                }
                setState(_open);
              },
      );
    } else {
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
    }

    // One shell, three faces. Width, colour, border and shadow morph together;
    // the face cross-fades faster than the shell moves, so the contents are
    // already legible while the pill is still growing. The count bubble rides
    // the shell's shoulder — half outside, the way a real badge sits — so it
    // lives OUTSIDE the clipped shell, in this unclipped stack.
    final shell = AnimatedContainer(
      key: _shellKey,
      duration: const Duration(milliseconds: 320),
      curve: _shellCurve,
      width: open ? _stepperWidth : _size,
      height: _size,
      decoration: BoxDecoration(
        // A quiet top-light on the teal gives the closed button its depth;
        // both stops collapse to the flat surface tone while open, so the
        // colour morph stays one continuous move.
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: open
              ? [cs.surfaceContainerHigh, cs.surfaceContainerHigh]
              : [
                  Color.lerp(cs.primary, Colors.white, 0.16)!,
                  Color.lerp(cs.primary, Colors.black, 0.10)!,
                ],
        ),
        borderRadius: BorderRadius.circular(_size / 2),
        border: Border.all(
          color: open ? cs.outlineVariant : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: (open ? Colors.black : cs.primary)
                .withValues(alpha: open ? 0.14 : 0.38),
            blurRadius: open ? 10 : 9,
            offset: const Offset(0, 3),
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        shell,
        // Only once there is a number to show: before that the glyph carries
        // its own drawn "+" badge, so a second bubble would say it twice.
        if (qty > 0)
          PositionedDirectional(
            top: -4,
            end: -3,
            child: AnimatedScale(
              scale: open ? 0 : 1,
              duration: context.motion(const Duration(milliseconds: 200)),
              curve: open ? Curves.easeIn : Curves.easeOutBack,
              child: _ShoulderBubble(count: qty),
            ),
          ),
      ],
    );
  }
}

/// The closed face: the logo's own box.
///
/// Empty, it wears the drawn teal "+" badge on its shoulder — the add-to-cart
/// glyph. Once the line exists the badge comes off and the live count bubble
/// takes that exact corner, so the plus really does *become* the number while
/// the box itself never moves.
///
/// Drawn transparent so the shell underneath supplies the teal — that is
/// what lets the shell's own colour morph stay seamless.
class _BagFace extends StatelessWidget {
  const _BagFace({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: ZbIcon(
              count > 0 ? ZbIconKind.bag : ZbIconKind.plusBox,
              size: 26,
              ink: cs.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The badge on the shell's shoulder, half outside like a real one. A ring in
/// the card's surface colour punches it out of both the teal shell and the
/// artwork behind.
class _ShoulderBubble extends StatelessWidget {
  const _ShoulderBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: context.zb.sale,
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: context.motion(const Duration(milliseconds: 200)),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Center(
          key: ValueKey('n$count'),
          child: Text(
            count > 9 ? '9+' : '$count',
            style: TextStyle(
              fontSize: count > 9 ? 7 : 9,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
