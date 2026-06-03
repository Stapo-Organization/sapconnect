import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Circular progress ring with a centered label. Color thresholds:
/// red (<50%), amber (<100%), green (100%). Used for cycle-count progress.
class ProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final double size;
  final double stroke;
  final Widget? center;
  final Color? color;
  final Color trackColor;

  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 120,
    this.stroke = 12,
    this.center,
    this.color,
    this.trackColor = const Color(0xFFE8EDF4),
  });

  Color get _autoColor {
    if (percent >= 100) return AppColors.success;
    if (percent >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? _autoColor;
    final p = (percent.clamp(0, 100)) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(value: value, color: c, stroke: stroke, track: trackColor),
            ),
          ),
          center ??
              Text(
                '${percent.round()}%',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;
  final Color track;

  _RingPainter({required this.value, required this.color, required this.stroke, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.65), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}
