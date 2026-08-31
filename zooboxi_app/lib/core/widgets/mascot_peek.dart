import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion/motion.dart';

/// The dog and cat from the logo, peeking over the top edge of [child].
///
/// The artwork is cut just above the wordmark so its lower band can hide
/// behind the card — which is why the card is pushed down by most of the
/// image height instead of all of it.
class MascotPeek extends StatelessWidget {
  const MascotPeek({
    super.key,
    required this.child,
    this.widthFactor = 0.78,
    this.maxWidth = 300,
    this.delay = const Duration(milliseconds: 160),
  });

  final Widget child;

  /// Image width as a fraction of the available width, capped at [maxWidth].
  final double widthFactor;
  final double maxWidth;
  final Duration delay;

  static const String asset = 'assets/brand/mascots_peek.png';

  /// Source aspect of `mascots_peek.png` (1201 × 537).
  static const double _aspect = 537 / 1201;

  /// Fraction of the image height that sits above the card; the rest is
  /// covered by it.
  static const double _reveal = 0.78;

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth;
        final imageWidth = math.min(available * widthFactor, maxWidth);
        final imageHeight = imageWidth * _aspect;

        Widget peek = Image.asset(
          asset,
          width: imageWidth,
          height: imageHeight,
          fit: BoxFit.contain,
        );
        if (!still) {
          peek = peek
              .animate()
              .fadeIn(delay: delay, duration: 320.ms)
              .moveY(
                begin: -12,
                end: 0,
                delay: delay,
                duration: 380.ms,
                curve: Motion.decelerate,
              );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(top: imageHeight * _reveal),
              child: child,
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
