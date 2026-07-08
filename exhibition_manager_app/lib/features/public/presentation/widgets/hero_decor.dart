import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Decorative layers shared by the public hero headers (landing + brand page):
/// a fine dot lattice, soft glass circles, and — on the brand page — a giant
/// blurred copy of the brand's own logo, which tints the header with each
/// brand's colours automatically (a zero-cost "dominant colour" wash).

/// Fine dot lattice, drawn very faint so it reads as texture, not pattern.
class DotsPattern extends StatelessWidget {
  final double opacity;
  const DotsPattern({super.key, this.opacity = 0.05});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _DotsPainter(Colors.white.withValues(alpha: opacity))),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 26.0;
    for (double x = 8; x < size.width; x += step) {
      for (double y = 8; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.color != color;
}

/// A soft translucent circle used as a glassy background ornament.
class GlassCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const GlassCircle({super.key, required this.size, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// The brand's own logo, oversized and heavily blurred, bleeding off the header
/// edge — every brand page gets a unique colour aura without any palette work.
class BlurredLogoWash extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final double opacity;
  const BlurredLogoWash({super.key, required this.logoUrl, this.size = 280, this.opacity = 0.5});

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
          child: CachedNetworkImage(
            imageUrl: logoUrl!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
