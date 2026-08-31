import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion/motion.dart';

/// The dog and cat from the logo, peeking over the top edge of [child].
///
/// The artwork is cut just above the wordmark so its lower band can hide
/// behind the card — which is why the card is pushed down by most of the
/// image height instead of all of it.
class MascotPeek extends StatefulWidget {
  const MascotPeek({
    super.key,
    required this.child,
    this.widthFactor = 0.78,
    this.maxWidth = 300,
    this.delay = const Duration(milliseconds: 160),
    this.idle = true,
  });

  final Widget child;

  /// Image width as a fraction of the available width, capped at [maxWidth].
  final double widthFactor;
  final double maxWidth;
  final Duration delay;

  /// Keeps the pair gently breathing after they arrive. An empty screen with
  /// a perfectly still mascot reads as a frozen frame; ±3pt is enough to say
  /// the app is alive without asking to be looked at.
  final bool idle;

  static const String asset = 'assets/brand/mascots_peek.png';

  /// Source aspect of `mascots_peek.png` (1201 × 537).
  static const double _aspect = 537 / 1201;

  /// Fraction of the image height that sits above the card; the rest is
  /// covered by it.
  static const double _reveal = 0.78;

  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// The bob starts only once the drop-in has finished, so the two moves never
  /// fight over the same pixels.
  Timer? _kick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.idle || context.reduceMotion) {
      _kick?.cancel();
      _kick = null;
      if (_bob.isAnimating) _bob.stop();
      return;
    }
    if (_kick != null || _bob.isAnimating) return;
    _kick = Timer(widget.delay + const Duration(milliseconds: 420), () {
      if (mounted) _bob.repeat();
    });
  }

  @override
  void dispose() {
    _kick?.cancel();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.maxWidth;
        final imageWidth =
            math.min(available * widget.widthFactor, widget.maxWidth);
        final imageHeight = imageWidth * MascotPeek._aspect;

        Widget peek = Image.asset(
          MascotPeek.asset,
          width: imageWidth,
          height: imageHeight,
          fit: BoxFit.contain,
        );
        if (!still) {
          peek = peek
              .animate()
              .fadeIn(delay: widget.delay, duration: 320.ms)
              .moveY(
                begin: -12,
                end: 0,
                delay: widget.delay,
                duration: 380.ms,
                curve: Motion.decelerate,
              );
          // A sine rather than a reversing tween: it leaves at rest, so the
          // pair never snap into position on the first frame.
          peek = AnimatedBuilder(
            animation: _bob,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 3 * math.sin(2 * math.pi * _bob.value)),
              child: child,
            ),
            child: peek,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(top: imageHeight * MascotPeek._reveal),
              child: widget.child,
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: Align(child: peek),
            ),
          ],
        );
      },
    );
  }
}
