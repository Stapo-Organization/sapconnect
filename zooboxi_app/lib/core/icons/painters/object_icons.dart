import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/zooboxi_tokens.dart';
import '../../widgets/sparkles.dart';
import 'icon_painter.dart';

/// The rest of the set: the things a customer taps that are not a tab.

/// The logo's heart, with its gloss on the start side.
class ZbHeartPainter extends ZbIconPainter {
  const ZbHeartPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  static const Rect _box = Rect.fromLTWH(1.8, 2.6, 20.4, 19.0);

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final path = heartPath(_box);
    if (fill > 0) canvas.drawPath(path, fillPaint(tint ?? ZbTokens.logoCoral));
    if (gloss > 0) {
      canvas.drawCircle(
        const Offset(8.2, 8.8),
        1.25,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9 * gloss),
      );
    }
    canvas.drawPath(path, strokePaint());
  }
}

/// A magnifier with a teal lens and a glint in it. The handle reads to the
/// bottom-end, so the whole glyph mirrors in Arabic.
class ZbSearchPainter extends ZbIconPainter {
  const ZbSearchPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  static const Offset _lens = Offset(10.4, 10.4);
  static const double _radius = 6.4;

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    if (fill > 0) {
      canvas.drawCircle(
        _lens,
        _radius,
        fillPaint(tint ?? ZbTokens.logoTeal, opacity: 0.42),
      );
      if (detailed) {
        canvas.drawPath(
          sparklePath(3.4, origin: const Offset(7.6, 7.6)),
          fillPaint(ZbTokens.creamLogo),
        );
      }
    }
    final line = strokePaint();
    canvas.drawCircle(_lens, _radius, line);
    canvas.drawLine(const Offset(15.1, 15.1), const Offset(19.6, 19.6), line);
  }
}

/// Four corner brackets and a scan line that can travel down the frame.
class ZbScanPainter extends ZbIconPainter {
  const ZbScanPainter({
    required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl,
    this.scanY = 0,
  });

  /// 0 = the line rests at the top of the frame, 1 = at the bottom.
  final double scanY;

  @override
  void draw(Canvas canvas) {
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(5.2, 5.2, 18.8, 18.8, const Radius.circular(4)),
        fillPaint(ZbTokens.logoTeal, opacity: 0.20),
      );
    }

    final line = strokePaint();
    final bracket = Path()
      ..moveTo(3.4, 9.0)
      ..lineTo(3.4, 6.4)
      ..arcToPoint(const Offset(6.4, 3.4), radius: const Radius.circular(3))
      ..lineTo(9.0, 3.4);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(12, 12);
      canvas.rotate(i * math.pi / 2);
      canvas.translate(-12, -12);
      canvas.drawPath(bracket, line);
      canvas.restore();
    }

    final y = 6.6 + 11.0 * scanY.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(6.6, y),
      Offset(17.4, y),
      strokePaint(width: 2.0, color: inkTo(tint ?? ZbTokens.logoTeal)),
    );
  }

  @override
  bool shouldRepaint(covariant ZbScanPainter old) =>
      super.shouldRepaint(old) || old.scanY != scanY;
}

/// A bubbly location pin with a paw print in it.
class ZbPinPainter extends ZbIconPainter {
  const ZbPinPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final drop = Path()
      ..moveTo(12, 21.6)
      ..quadraticBezierTo(6.0, 14.8, 5.9, 10.0)
      ..arcToPoint(const Offset(18.1, 10.0), radius: const Radius.circular(6.1))
      ..quadraticBezierTo(18.0, 14.8, 12, 21.6)
      ..close();

    if (fill > 0) canvas.drawPath(drop, fillPaint(tint ?? ZbTokens.logoCoral));
    canvas.drawPath(drop, strokePaint());

    // The paw stays legible in both states: ink on the empty pin, cream once
    // the pin itself is coral.
    final paw = Paint()..color = Color.lerp(ink, ZbTokens.creamLogo, fill)!;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 11.6), width: 3.8, height: 3.2),
      paw,
    );
    // Three toes inside a 23pt pin merge into one blob; two hold apart.
    final toes = detailed
        ? const [Offset(9.4, 8.6), Offset(12, 7.7), Offset(14.6, 8.6)]
        : const [Offset(10.2, 8.2), Offset(13.8, 8.2)];
    for (final toe in toes) {
      canvas.drawCircle(toe, detailed ? 0.95 : 1.15, paw);
    }

    if (gloss > 0) {
      canvas.drawCircle(
        const Offset(8.4, 6.8),
        0.8,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.85 * gloss),
      );
    }
  }
}

/// A rounded bell with a clapper and one sparkle at its end shoulder.
class ZbBellPainter extends ZbIconPainter {
  const ZbBellPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final bell = Path()
      ..moveTo(5.4, 16.2)
      ..quadraticBezierTo(7.0, 15.4, 7.0, 11.6)
      ..arcToPoint(const Offset(17.0, 11.6), radius: const Radius.circular(5.0))
      ..quadraticBezierTo(17.0, 15.4, 18.6, 16.2)
      ..close();

    if (fill > 0) {
      canvas.drawPath(bell, fillPaint(tint ?? ZbTokens.cardboard));
      canvas.drawCircle(const Offset(12, 5.3), 1.2, fillPaint(ZbTokens.cardboard));
      canvas.drawCircle(const Offset(12, 18.3), 1.6, fillPaint(ZbTokens.cardboard));
    }
    if (gloss > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(9.0, 13.6)
          ..quadraticBezierTo(9.0, 9.8, 11.0, 8.4),
        strokePaint(
          width: 1.4,
          color: ZbTokens.creamLogo.withValues(alpha: 0.85 * gloss),
        ),
      );
    }

    final line = strokePaint();
    canvas.drawPath(bell, line);
    canvas.drawCircle(const Offset(12, 5.3), 1.2, line);
    canvas.drawCircle(const Offset(12, 18.3), 1.6, line);

    if (detailed) {
      canvas.drawPath(
        sparklePath(3.4, origin: const Offset(18.2, 4.4)),
        Paint()..color = inkTo(ZbTokens.sparkAmber),
      );
    }
  }
}

/// Pad and four toes.
class ZbPawPainter extends ZbIconPainter {
  const ZbPawPainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  static const List<Offset> _toes = [
    Offset(6.5, 11.2),
    Offset(9.9, 7.9),
    Offset(14.1, 7.9),
    Offset(17.5, 11.2),
  ];

  @override
  void draw(Canvas canvas) {
    final pad = Rect.fromCenter(
      center: const Offset(12, 16.2),
      width: 9.2,
      height: 7.6,
    );
    if (fill > 0) {
      canvas.drawOval(pad, fillPaint(tint ?? ZbTokens.cardboard));
      for (final toe in _toes) {
        canvas.drawOval(
          Rect.fromCenter(center: toe, width: 3.5, height: 4.3),
          fillPaint(tint ?? ZbTokens.cardboard),
        );
      }
    }
    if (gloss > 0) {
      canvas.drawCircle(
        const Offset(8.9, 13.9),
        0.8,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9 * gloss),
      );
    }

    final line = strokePaint();
    canvas.drawOval(pad, line);
    for (final toe in _toes) {
      canvas.drawOval(
        Rect.fromCenter(center: toe, width: 3.5, height: 4.3),
        line,
      );
    }
  }
}

/// The confetti star, as an icon — the same path [Sparkle] paints.
class ZbSparklePainter extends ZbIconPainter {
  const ZbSparklePainter({required super.ink,
    required super.fill,
    required super.size,
    super.tint,
    super.rtl});

  @override
  void draw(Canvas canvas) {
    canvas.drawPath(
      sparklePath(19.2, origin: const Offset(2.4, 2.4)),
      Paint()..color = tint ?? inkTo(ZbTokens.sparkAmber),
    );
  }
}
