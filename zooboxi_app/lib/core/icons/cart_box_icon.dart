import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/data/cart_controller.dart';
import '../motion/motion.dart';
import 'zb_icons.dart';

/// The cart tab's box, watching the basket.
///
/// When a line lands the box *reacts*: it hops, its lid flies open and its
/// smile widens. That is the app's confirmation from three screens away —
/// the badge tells you the number, the box tells you something arrived. A
/// removal only gets a small dip: taking something out is not a celebration.
class CartBoxIcon extends ConsumerStatefulWidget {
  const CartBoxIcon({super.key, this.size = 23, this.fill = 0, this.ink});

  final double size;
  final double fill;
  final Color? ink;

  @override
  ConsumerState<CartBoxIcon> createState() => _CartBoxIconState();
}

class _CartBoxIconState extends ConsumerState<CartBoxIcon>
    with SingleTickerProviderStateMixin {
  static const Duration _celebrate = Duration(milliseconds: 600);
  static const Duration _dipFor = Duration(milliseconds: 320);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _celebrate,
  );

  bool _dipping = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _play({required bool dip}) {
    if (context.reduceMotion) return;
    _dipping = dip;
    _c.duration = dip ? _dipFor : _celebrate;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(cartCountProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _play(dip: next < previous);
    });

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t == 0) return _icon(0, 0.6);

        if (_dipping) {
          return Transform.translate(
            offset: Offset(0, 3 * math.sin(math.pi * t)),
            child: _icon(0, 0.6),
          );
        }

        final lid = t < 0.45
            ? Curves.easeOutBack.transform(t / 0.45)
            : 1 - Curves.easeIn.transform((t - 0.45) / 0.55);
        final lift = t < 0.45
            ? Curves.easeOut.transform(t / 0.45)
            : (t < 0.8 ? 1 - Curves.easeIn.transform((t - 0.45) / 0.35) : 0.0);
        // The landing squash: it arrives wide and short, then springs back.
        final land =
            t < 0.8 ? 0.0 : 1 - Curves.easeOutBack.transform((t - 0.8) / 0.2);
        final smile = 0.6 + 0.4 * math.sin(math.pi * t);

        return Transform.translate(
          offset: Offset(0, -5 * lift),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 + 0.08 * land, 1 - 0.10 * land, 1),
            child: _icon(lid.clamp(0.0, 1.0), smile),
          ),
        );
      },
    );
  }

  Widget _icon(double lidOpen, double smile) => ZbIcon(
        ZbIconKind.cart,
        size: widget.size,
        fill: widget.fill,
        ink: widget.ink,
        lidOpen: lidOpen,
        smile: smile,
      );
}
