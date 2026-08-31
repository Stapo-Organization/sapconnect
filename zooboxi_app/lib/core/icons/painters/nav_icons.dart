import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/zooboxi_tokens.dart';
import 'icon_painter.dart';

/// The four tab glyphs plus the add-to-cart box.

/// A kawaii pet house: cream walls, a cardboard roof that overhangs, a coral
/// arched door and — once it is fully filled — a heart over the door.
class ZbHomePainter extends ZbIconPainter {
  const ZbHomePainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  @override
  void draw(Canvas canvas) {
    final walls = RRect.fromLTRBR(4.0, 10.2, 20.0, 21.2, const Radius.circular(3.2));
    final roof = Path()
      ..moveTo(2.2, 10.4)
      ..lineTo(10.5, 3.9)
      ..quadraticBezierTo(12, 2.85, 13.5, 3.9)
      ..lineTo(21.8, 10.4)
      ..close();
    final door = Path()
      ..moveTo(9.8, 21.2)
      ..lineTo(9.8, 17.8)
      ..arcToPoint(const Offset(14.2, 17.8), radius: const Radius.circular(2.2))
      ..lineTo(14.2, 21.2);

    if (fill > 0) {
      canvas.drawRRect(walls, fillPaint(ZbTokens.creamLogo));
      canvas.drawPath(roof, fillPaint(ZbTokens.cardboard));
      canvas.drawPath(
        Path.from(door)..close(),
        fillPaint(tint ?? ZbTokens.logoCoral),
      );
    }
    if (gloss > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(6.6, 9.2)
          ..quadraticBezierTo(8.6, 6.9, 10.4, 5.6),
        strokePaint(
          width: 1.4,
          color: ZbTokens.creamLogo.withValues(alpha: 0.85 * gloss),
        ),
      );
    }

    final line = strokePaint();
    canvas.drawRRect(walls, line);
    canvas.drawPath(roof, line);
    canvas.drawPath(door, line);

    // The heart is the last thing to arrive — it belongs to the fully lit
    // state, not to the outline, and only where it is bigger than a smudge.
    final heartIn = detailed ? ((fill - 0.7) / 0.3).clamp(0.0, 1.0) : 0.0;
    if (heartIn > 0) {
      canvas.drawPath(
        heartPath(const Rect.fromLTWH(10.2, 11.0, 3.6, 3.3)),
        Paint()..color = ZbTokens.logoCoral.withValues(alpha: heartIn),
      );
    }
  }
}

/// Four sticker tiles, one per logo colour.
class ZbCategoriesPainter extends ZbIconPainter {
  const ZbCategoriesPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  static const List<Color> _tiles = [
    ZbTokens.logoTeal,
    ZbTokens.logoCoral,
    ZbTokens.cardboard,
    ZbTokens.creamLogo,
  ];

  @override
  void draw(Canvas canvas) {
    final line = strokePaint();
    var i = 0;
    for (final top in const [2.6, 13.0]) {
      for (final left in const [2.6, 13.0]) {
        final tile = RRect.fromLTRBR(
          left,
          top,
          left + 8.4,
          top + 8.4,
          const Radius.circular(2.7),
        );
        if (fill > 0) canvas.drawRRect(tile, fillPaint(_tiles[i]));
        if (gloss > 0 && i == 0) {
          canvas.drawCircle(
            Offset(left + 2.4, top + 2.4),
            0.85,
            Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9 * gloss),
          );
        }
        canvas.drawRRect(tile, line);
        i++;
      }
    }
  }
}

/// Draws the logo's own smiling box. Shared by the cart tab and the
/// add-to-cart glyph so the two are unmistakably the same object.
mixin BoxDrawing on ZbIconPainter {
  /// Flaps open outward from the hinges at the box's top corners.
  static const double _openAngle = 38 * math.pi / 180;

  void drawSmilingBox(
    Canvas canvas, {
    required double lidOpen,
    required double smile,
    double strokeWidth = ZbIconPainter.strokeUnits,
  }) {
    final line = strokePaint(width: strokeWidth);
    final face = RRect.fromLTRBR(3.2, 8.2, 20.8, 20.8, const Radius.circular(3.6));

    // The inner rim only ever shows through the gap the flaps leave; the face
    // is painted over it, so nothing has to be clipped.
    if (lidOpen > 0.02) {
      canvas.drawRRect(
        RRect.fromLTRBR(4.8, 6.2, 19.2, 10.6, const Radius.circular(2.4)),
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.55 + 0.45 * fill),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(4.8, 6.2, 19.2, 10.6, const Radius.circular(2.4)),
        line,
      );
    }

    if (fill > 0) canvas.drawRRect(face, fillPaint(ZbTokens.cardboard));
    if (gloss > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(5.6, 12.6)
          ..quadraticBezierTo(5.8, 10.6, 7.6, 10.0),
        strokePaint(
          width: strokeWidth * 0.62,
          color: ZbTokens.creamLogo.withValues(alpha: 0.85 * gloss),
        ),
      );
    }
    canvas.drawRRect(face, line);

    // Two dot eyes and the smile: the box is a face, which is the whole point
    // of the mark.
    final eye = Paint()..color = featureInk;
    canvas.drawCircle(const Offset(9.6, 11.8), 0.95, eye);
    canvas.drawCircle(const Offset(14.4, 11.8), 0.95, eye);
    canvas.drawPath(
      Path()
        ..moveTo(9.0, 14.4)
        ..quadraticBezierTo(12, 14.4 + 3.4 * smile, 15.0, 14.4),
      strokePaint(
        width: strokeWidth * 0.92,
        color: Color.lerp(ink, ZbTokens.coralDark, fill)!,
      ),
    );

    final flap = RRect.fromLTRBR(0, -3.0, 8.1, 0.2, const Radius.circular(1.5));
    final flapFill = fill > 0
        ? fillPaint(Color.lerp(ZbTokens.cardboard, Colors.white, 0.22)!)
        : null;
    for (final start in const [true, false]) {
      canvas.save();
      canvas.translate(start ? 3.6 : 20.4, 8.4);
      if (!start) canvas.scale(-1, 1);
      canvas.rotate(-_openAngle * lidOpen);
      if (flapFill != null) canvas.drawRRect(flap, flapFill);
      canvas.drawRRect(flap, line);
      canvas.restore();
    }
  }
}

/// The cart tab: the logo's box, with a lid that can open and a smile that can
/// widen — both driven from outside so the tab can celebrate an add.
class ZbCartPainter extends ZbIconPainter with BoxDrawing {
  const ZbCartPainter({
    required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl,
    this.lidOpen = 0,
    this.smile = 0.6,
  });

  final double lidOpen;
  final double smile;

  @override
  void draw(Canvas canvas) =>
      drawSmilingBox(canvas, lidOpen: lidOpen, smile: smile);

  @override
  bool shouldRepaint(covariant ZbCartPainter old) =>
      super.shouldRepaint(old) || old.lidOpen != lidOpen || old.smile != smile;
}

/// A happy round face: closed ^-eyes, a small smile, blush and a cardboard cap.
class ZbAccountPainter extends ZbIconPainter {
  const ZbAccountPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  static const Offset _centre = Offset(12, 12.4);
  static const double _radius = 8.3;

  @override
  void draw(Canvas canvas) {
    if (fill > 0) {
      canvas.drawCircle(_centre, _radius, fillPaint(ZbTokens.creamLogo));
      if (detailed) {
        final blush = fillPaint(ZbTokens.logoCoral, opacity: 0.85);
        canvas.drawCircle(const Offset(7.4, 15.2), 1.5, blush);
        canvas.drawCircle(const Offset(16.6, 15.2), 1.5, blush);
        canvas.drawPath(
          Path()
            ..moveTo(4.19, 9.6)
            ..arcToPoint(const Offset(19.81, 9.6), radius: const Radius.circular(_radius))
            ..quadraticBezierTo(12, 11.6, 4.19, 9.6)
            ..close(),
          fillPaint(tint ?? ZbTokens.cardboard),
        );
      }
    }
    if (gloss > 0) {
      canvas.drawCircle(
        const Offset(7.0, 11.0),
        0.9,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9 * gloss),
      );
    }

    final line = strokePaint();
    canvas.drawCircle(_centre, _radius, line);
    // The cap is the first thing to go small: two more arcs across the top of
    // a 23pt circle turn the face into a scribble.
    if (detailed) {
      canvas.drawPath(
        Path()
          ..moveTo(4.19, 9.6)
          ..arcToPoint(const Offset(19.81, 9.6), radius: const Radius.circular(_radius)),
        line,
      );
      canvas.drawPath(
        Path()..moveTo(4.19, 9.6)..quadraticBezierTo(12, 11.6, 19.81, 9.6),
        line,
      );
    }

    final eyes = strokePaint(
      width: ZbIconPainter.strokeUnits * 0.86,
      color: featureInk,
    );
    for (final x in const [9.0, 15.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 1.6, 13.2)
          ..quadraticBezierTo(x, 11.6, x + 1.6, 13.2),
        eyes,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(10.2, 15.9)
        ..quadraticBezierTo(12, 18.1, 13.8, 15.9),
      eyes,
    );
  }
}

/// The add-to-cart glyph: the same smiling box with its lid shut, wearing a
/// teal "+" badge on its end shoulder.
class ZbPlusBoxPainter extends ZbIconPainter with BoxDrawing {
  const ZbPlusBoxPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  /// The box shrinks so the badge has a corner of its own to sit in.
  static const double _boxScale = 0.86;

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    canvas.save();
    canvas.translate(12, 21.8);
    canvas.scale(_boxScale);
    canvas.translate(-12, -21.8);
    drawSmilingBox(
      canvas,
      lidOpen: 0,
      smile: 0.6,
      strokeWidth: ZbIconPainter.strokeUnits / _boxScale,
    );
    canvas.restore();

    // A solid disc, not a ring around a fill: an outlined circle with a thin
    // cross in it reads as a crosshair, which is the one thing this badge must
    // never look like. Warm outline, teal body, bold cream "+", and the badge
    // sits ON the box's end shoulder the way a real one does.
    const badge = Offset(18.2, 5.6);
    const radius = 4.4;
    canvas.drawCircle(badge, radius, Paint()..color = tint ?? ZbTokens.logoTeal);
    canvas.drawCircle(badge, radius, strokePaint());

    // The visible teal is the disc *minus its own outline*; a cross measured
    // against the full diameter overflows that and turns the badge into a
    // cream blob, so the arms are sized against the inner disc instead.
    // Heaviest weight that still reads as a "+" at this diameter: past it the
    // four arms are shorter than the stroke is thick and the cross fuses into
    // a cream blob.
    final width = detailed ? 2.0 : 2.3;
    const inner = 2 * (radius - ZbIconPainter.strokeUnits / 2);
    final arm = (inner - 0.6 - width) / 2;
    final plus = strokePaint(width: width, color: ZbTokens.creamLogo);
    canvas.drawLine(
      Offset(badge.dx - arm, badge.dy),
      Offset(badge.dx + arm, badge.dy),
      plus,
    );
    canvas.drawLine(
      Offset(badge.dx, badge.dy - arm),
      Offset(badge.dx, badge.dy + arm),
      plus,
    );
  }
}
