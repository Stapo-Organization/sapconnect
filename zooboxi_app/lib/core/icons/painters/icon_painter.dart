import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/zooboxi_tokens.dart';

/// Base for every Zooboxi icon painter.
///
/// Icons are drawn in the logo's hand: one 24-unit grid, one stroke weight, no
/// sharp corners. [fill] is the only state an icon carries — 0 is the quiet
/// outline, 1 is the full kawaii sticker, and everything between crossfades the
/// fills so a tab selection can animate through it.
abstract class ZbIconPainter extends CustomPainter {
  const ZbIconPainter({
    required this.ink,
    required this.fill,
    required this.size,
    this.tint,
    this.rtl = false,
  });

  final Color ink;
  final double fill;

  /// The size the icon is actually painted at, which decides how much detail
  /// it can carry. See [detailed].
  final double size;

  /// Overrides the icon's signature accent (the lens, the badge, the pin).
  final Color? tint;

  final bool rtl;

  /// The design grid. Every coordinate in this library is in these units.
  static const double grid = 24;

  /// The one outline weight in the set: 2.2/24 of the rendered size.
  static const double strokeUnits = 2.2;

  /// Below this the tertiary detail is noise, not character: a 1-unit gloss
  /// dot is a third of a pixel at tab size. Optical sizing, the way a type
  /// family carries a text cut and a display cut.
  static const double detailFloor = 28;

  /// Whether this instance is large enough for its tertiary features — blush,
  /// gloss, the heart over the door, the sparkle in the lens.
  bool get detailed => size >= detailFloor;

  /// Whether the whole glyph flips in Arabic. True only where the shape has a
  /// reading direction — a magnifier handle, a badge on the end shoulder, a
  /// gloss highlight that must catch the light from the start edge.
  bool get mirrored => false;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / grid;
    canvas.save();
    canvas.scale(scale);
    if (rtl && mirrored) {
      canvas.translate(grid, 0);
      canvas.scale(-1, 1);
    }
    draw(canvas);
    canvas.restore();
  }

  /// Draw in grid units; the canvas is already scaled.
  void draw(Canvas canvas);

  Paint strokePaint({double width = strokeUnits, Color? color}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color ?? ink;

  /// A fill only exists in proportion to [fill] — that is what makes the
  /// outline state and the sticker state the same painter.
  Paint fillPaint(Color color, {double opacity = 1}) =>
      Paint()..color = color.withValues(alpha: color.a * fill * opacity);

  /// The logo's gloss appears only once a shape is actually filled — and only
  /// where there is room to see it.
  double get gloss =>
      detailed ? ((fill - 0.5) / 0.5).clamp(0.0, 1.0) : 0.0;

  /// A stroked detail that turns from ink into its brand colour as the icon
  /// fills — a smile or a scan line must stay visible at fill 0.
  Color inkTo(Color target) => Color.lerp(ink, target, fill)!;

  /// Ink for a feature drawn ON a fill — eyes, a smile. The outline can stay
  /// theme-coloured because it reads against the page, but a cream eye on a
  /// cream face is a blank face, so interior detail walks back to the logo's
  /// warm brown as the shape fills.
  Color get featureInk => Color.lerp(ink, ZbTokens.inkWarm, fill)!;

  @override
  bool shouldRepaint(covariant ZbIconPainter old) =>
      old.ink != ink ||
      old.fill != fill ||
      old.size != size ||
      old.tint != tint ||
      old.rtl != rtl;
}

/// The logo's heart, fitted to [r]. Shared by the heart icon and the house's
/// little heart so both carry the same curve.
Path heartPath(Rect r) {
  double x(double f) => r.left + r.width * f;
  double y(double f) => r.top + r.height * f;
  return Path()
    ..moveTo(x(0.5), y(0.94))
    ..cubicTo(x(0.06), y(0.62), x(0.02), y(0.28), x(0.26), y(0.14))
    ..cubicTo(x(0.40), y(0.05), x(0.50), y(0.18), x(0.50), y(0.28))
    ..cubicTo(x(0.50), y(0.18), x(0.60), y(0.05), x(0.74), y(0.14))
    ..cubicTo(x(0.98), y(0.28), x(0.94), y(0.62), x(0.5), y(0.94))
    ..close();
}
