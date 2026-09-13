import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The faint paw wallpaper the express home's coloured surfaces wear.
///
/// One paw, tiled on a 66-point grid and the whole sheet tilted fourteen
/// degrees, so it reads as a printed pattern rather than a row of stamps. It
/// is texture, not decoration: white at seven percent on a deep colour, or
/// the ink at four and a half on paper, low enough that the eye feels a
/// surface and never reads a shape. Painted once into its own layer, so a
/// clock ticking on top of it never repaints the wallpaper.
class PawWallpaper extends StatelessWidget {
  const PawWallpaper({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.07,
    this.tile = 66,
  });

  /// The wallpaper on paper: the brand ink at a whisper.
  const PawWallpaper.onPaper({super.key, this.tile = 66})
    : color = const Color(0xFF2C3E2D),
      opacity = 0.045;

  final Color color;
  final double opacity;

  /// The grid pitch in points; the paw itself is about six tenths of it.
  final double tile;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _PawWallpaperPainter(color.withValues(alpha: opacity), tile),
        size: Size.infinite,
      ),
    ),
  );
}

class _PawWallpaperPainter extends CustomPainter {
  const _PawWallpaperPainter(this.color, this.tile);

  final Color color;
  final double tile;

  static const double _tilt = -14 * math.pi / 180;

  /// The paw, drawn in an 80-unit box: four toes and a pad, set at the slight
  /// angle a real print lands at.
  static Path _paw() {
    final p = Path();
    for (final (cx, cy, r) in const [
      (22.0, 24.0, 5.0),
      (34.0, 17.0, 5.0),
      (48.0, 19.0, 5.0),
      (58.0, 30.0, 4.5),
    ]) {
      p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    }
    p
      ..moveTo(40, 27)
      ..cubicTo(32, 27, 25, 35, 25, 43)
      ..arcToPoint(
        const Offset(32, 50),
        radius: const Radius.circular(7),
        clockwise: false,
      )
      ..cubicTo(35, 50, 37, 48.5, 40, 48.5)
      ..cubicTo(43, 48.5, 45, 50, 48, 50)
      ..arcToPoint(
        const Offset(55, 43),
        radius: const Radius.circular(7),
        clockwise: false,
      )
      ..cubicTo(55, 35, 48, 27, 40, 27)
      ..close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..color = color;
    final paw = _paw();
    final scale = tile / 80;

    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_tilt);

    // The tilted sheet has to outrun the box's corners: half the diagonal,
    // plus one tile of slack, in every direction.
    final reach =
        math.sqrt(size.width * size.width + size.height * size.height) / 2 +
        tile;
    final count = (reach / tile).ceil();
    for (var i = -count; i <= count; i++) {
      for (var j = -count; j <= count; j++) {
        canvas
          ..save()
          ..translate(i * tile, j * tile)
          ..scale(scale)
          ..drawPath(paw, paint)
          ..restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PawWallpaperPainter old) =>
      old.color != color || old.tile != tile;
}
