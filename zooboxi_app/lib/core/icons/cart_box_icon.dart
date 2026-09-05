import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/data/cart_controller.dart';
import '../motion/motion.dart';
import 'zb_icons.dart';

/// The cart tab's shopping bag, watching the basket.
///
/// When a line lands the bag *reacts*: it hops and gives a happy little tilt,
/// then lands with a squash. That is the app's confirmation from three
/// screens away — the badge tells you the number, the bag tells you something
/// arrived. A removal only gets a small dip: taking something out is not a
/// celebration.
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
        if (t == 0) return _icon();

        if (_dipping) {
          return Transform.translate(
            offset: Offset(0, 3 * math.sin(math.pi * t)),
            child: _icon(),
          );
        }

        final lift = t < 0.45
            ? Curves.easeOut.transform(t / 0.45)
            : (t < 0.8 ? 1 - Curves.easeIn.transform((t - 0.45) / 0.35) : 0.0);
        // The happy tilt: two quick sways that die out on the way down —
        // the bag wiggles like something just dropped into it.
        final tilt = 0.14 * math.sin(2 * math.pi * t) * (1 - t);
        // The landing squash: it arrives wide and short, then springs back.
        final land =
            t < 0.8 ? 0.0 : 1 - Curves.easeOutBack.transform((t - 0.8) / 0.2);

        return Transform.translate(
          offset: Offset(0, -5 * lift),
          child: Transform.rotate(
            angle: tilt,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform:
                  Matrix4.diagonal3Values(1 + 0.08 * land, 1 - 0.10 * land, 1),
              child: _icon(),
            ),
          ),
        );
      },
    );
  }

  Widget _icon() => ZbIcon(
        ZbIconKind.bag,
        size: widget.size,
        fill: widget.fill,
        ink: widget.ink,
      );
}
