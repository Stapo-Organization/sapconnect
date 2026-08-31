import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/zooboxi_tokens.dart';
import '../motion/motion.dart';

/// The logo's confetti vocabulary — 4-point sparkles and small hearts.
///
/// These are decor: they carry no meaning, never sit above content in the
/// reading order, and are always wrapped in an [IgnorePointer] by the field.

/// A 4-point kawaii star: points at N/E/S/W with the edges pulled toward the
/// centre, so the arms read as concave rather than as a diamond.
class Sparkle extends StatelessWidget {
  const Sparkle({
    super.key,
    required this.size,
    required this.color,
    this.rotation = 0,
  });

  final double size;
  final Color color;

  /// Radians. A little rotation keeps a field of sparkles from looking stamped.
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final star = CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color),
    );
    return SizedBox.square(
      dimension: size,
      child: rotation == 0 ? star : Transform.rotate(angle: rotation, child: star),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  /// Where each arm's control point sits along the centre→chord-midpoint line,
  /// as a fraction of size. The chord midpoint is at 0.25: at or above it the
  /// shape is a diamond (0.28 rendered as a fat rhombus); the logo's pointed
  /// sparkles sit well inside, at 0.12.
  static const double _pull = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final p = size.width * _pull;
    final path = Path()
      ..moveTo(c, 0)
      ..quadraticBezierTo(c + p, c - p, size.width, c)
      ..quadraticBezierTo(c + p, c + p, c, size.height)
      ..quadraticBezierTo(c - p, c + p, 0, c)
      ..quadraticBezierTo(c - p, c - p, c, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// A tiny rounded heart, drawn rather than iconified so the outline weight
/// matches the logo's thick warm ink.
class Heart extends StatelessWidget {
  const Heart({
    super.key,
    required this.size,
    this.color = ZbTokens.logoCoral,
    this.outline,
    this.rotation = 0,
  });

  final double size;
  final Color color;

  /// Warm ink stroke. Null draws the heart flat — right at low alpha, where a
  /// stroke would only muddy the shape.
  final Color? outline;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final heart = CustomPaint(
      size: Size.square(size),
      painter: _HeartPainter(color, outline),
    );
    return SizedBox.square(
      dimension: size,
      child: rotation == 0 ? heart : Transform.rotate(angle: rotation, child: heart),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter(this.color, this.outline);

  final Color color;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.94)
      ..cubicTo(w * 0.06, h * 0.62, w * 0.02, h * 0.28, w * 0.26, h * 0.14)
      ..cubicTo(w * 0.40, h * 0.05, w * 0.50, h * 0.18, w * 0.50, h * 0.28)
      ..cubicTo(w * 0.50, h * 0.18, w * 0.60, h * 0.05, w * 0.74, h * 0.14)
      ..cubicTo(w * 0.98, h * 0.28, w * 0.94, h * 0.62, w * 0.5, h * 0.94)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final stroke = outline;
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color || old.outline != outline;
}

/// One sparkle's placement inside a [SparkleField].
@immutable
class SparkleSpec {
  const SparkleSpec({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    this.delay = Duration.zero,
    this.rotation = 0,
  });

  /// Fractions of the field, 0..1. [dx] is logical: 0 is the *start* edge, so
  /// a field mirrors itself in Arabic without a second table of numbers.
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final Duration delay;
  final double rotation;
}

/// A decor layer of sparkles positioned by fraction over whatever it is
/// stacked on. Sizes itself to the parent, so give it a bounded box.
class SparkleField extends StatelessWidget {
  const SparkleField({
    super.key,
    required this.sparkles,
    this.twinkle = false,
  });

  final List<SparkleSpec> sparkles;

  /// Adds a short two-cycle pulse after the entrance, then rests. Never loops:
  /// a permanently animating background is a battery and attention tax.
  final bool twinkle;

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (!w.isFinite || !h.isFinite) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final s in sparkles)
                PositionedDirectional(
                  start: w * s.dx - s.size / 2,
                  top: h * s.dy - s.size / 2,
                  child: _animate(
                    Sparkle(size: s.size, color: s.color, rotation: s.rotation),
                    s.delay,
                    still,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _animate(Widget child, Duration delay, bool still) {
    if (still) return child;

    var effects = child
        .animate()
        .fadeIn(delay: delay, duration: 260.ms)
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          delay: delay,
          duration: 420.ms,
          curve: Motion.spring,
        );

    if (twinkle) {
      effects = effects
          .then(delay: 120.ms)
          .scaleXY(begin: 1, end: 1.22, duration: 340.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(begin: 1, end: 1 / 1.22, duration: 340.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(begin: 1, end: 1.14, duration: 300.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(begin: 1, end: 1 / 1.14, duration: 300.ms, curve: Curves.easeInOut);
    }

    return effects;
  }
}
