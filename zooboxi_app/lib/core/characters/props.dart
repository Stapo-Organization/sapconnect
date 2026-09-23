import 'package:flutter/material.dart';

import '../../app/theme/zooboxi_tokens.dart';

/// Props drawn in code, in the characters' own hand: flat brand fills, the
/// logo's warm-brown outline (never black), a white die-cut ring around the
/// whole object so it sits in the same world as the stickers.

const Color _ink = Color(0xFF5A2C2F);

/// An empty food bowl — the empty basket, said the way a pet would say it.
class EmptyBowl extends StatelessWidget {
  const EmptyBowl({super.key, this.width = 130});

  final double width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, width * 0.56),
      painter: _BowlPainter(),
    ),
  );
}

class _BowlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s);

    final body = Path()
      ..moveTo(22, 44)
      ..quadraticBezierTo(26, 102, 64, 106)
      ..lineTo(136, 106)
      ..quadraticBezierTo(174, 102, 178, 44)
      ..close();
    final rim = Rect.fromCenter(
      center: const Offset(100, 44),
      width: 160,
      height: 40,
    );
    final inside = Rect.fromCenter(
      center: const Offset(100, 46),
      width: 124,
      height: 24,
    );

    // The ring: the whole silhouette, stroked wide in white first.
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, ring);
    canvas.drawOval(rim, ring);

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, Paint()..color = ZbTokens.teal);
    canvas.drawPath(body, outline);
    canvas.drawPath(
      Path()
        ..moveTo(40, 62)
        ..quadraticBezierTo(46, 92, 70, 96),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(rim, Paint()..color = ZbTokens.logoTeal);
    canvas.drawOval(rim, outline);
    canvas.drawOval(inside, Paint()..color = const Color(0xFFE8DAC2));

    // A paw on the front, in cream.
    final paw = Paint()..color = ZbTokens.cream;
    canvas.translate(88, 64);
    canvas.scale(0.26);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 64), width: 48, height: 38),
      paw,
    );
    for (final c in const [
      Offset(27, 41),
      Offset(43, 30),
      Offset(60, 30),
      Offset(75, 41),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: 19, height: 22), paw);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A finish flag for a progress bar that a character runs along.
class FinishFlag extends StatelessWidget {
  const FinishFlag({super.key, this.color = ZbTokens.coral, this.height = 30});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(height * 22 / 30, height),
      painter: _FlagPainter(color),
    ),
  );
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / 30);
    canvas.drawLine(
      const Offset(4, 2),
      const Offset(4, 28),
      Paint()
        ..color = _ink
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(5, 3)
      ..lineTo(18, 3)
      ..lineTo(14.5, 8)
      ..lineTo(18, 13)
      ..lineTo(5, 13)
      ..close();
    canvas.drawPath(flag, Paint()..color = color);
    canvas.drawPath(
      flag,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.color != color;
}
