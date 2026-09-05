import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/painters/icon_painter.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';

/// ════════════════════════════════════════════════════════════════════
/// The family program's own art — drawn in the mascot's hand.
///
/// Everything «عائلة زوبوكسي» shows that is not a photo or a word comes from
/// here: the paw coin the whole currency is counted in, the four reward
/// stickers, the five mission stickers, and the handful of small marks (lock,
/// check, book, bulb) that replace Material's cold outlines. One grid, one
/// warm outline weight, colour first and ink on top — so a coin on the account
/// header and a gift on a scratch card are visibly the same drawing.
/// ════════════════════════════════════════════════════════════════════

/// The stroke portraits and stickers use: lighter than the tab glyphs, whose
/// 2.2 is tuned for 24pt. A sticker is drawn at 40–80pt, and the mascot's own
/// line is a hair under a tenth of its head.
const double kStickerStroke = 1.5;

/// A filled shape with the warm outline on top — the one way every sticker is
/// built. Shared by the portraits too.
extension StickerCanvas on Canvas {
  void sticker(Path path, Color color, Paint line) {
    drawPath(path, Paint()..color = color);
    drawPath(path, line);
  }

  void stickerOval(Rect rect, Color color, Paint line) {
    drawOval(rect, Paint()..color = color);
    drawOval(rect, line);
  }

  void stickerRRect(RRect rect, Color color, Paint line) {
    drawRRect(rect, Paint()..color = color);
    drawRRect(rect, line);
  }

  void stickerCircle(Offset c, double r, Color color, Paint line) {
    drawCircle(c, r, Paint()..color = color);
    drawCircle(c, r, line);
  }
}

/// Base for everything on this sheet: full fill, the sticker stroke, and the
/// mascot's brown ink regardless of theme — a sticker is an object on the
/// page, not a control, so it does not go cream in the dark the way a tab
/// glyph does.
abstract class StickerPainter extends ZbIconPainter {
  const StickerPainter({required super.size, super.tint})
      : super(ink: ZbTokens.inkWarm, fill: 1);

  Paint get line => strokePaint(width: kStickerStroke);
  Paint thin([double w = 1.1]) => strokePaint(width: w);

  /// A soft white highlight — the gloss every filled shape in the logo wears.
  void glossAt(Canvas canvas, Offset c, {double w = 3.2, double h = 1.7, double angle = -0.55, double alpha = 0.55}) {
    if (!detailed) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  /// A 4-point sparkle in the logo's amber (or [color]).
  void sparkleAt(Canvas canvas, Offset c, double side, {Color? color}) {
    canvas.drawPath(
      sparklePath(side, origin: Offset(c.dx - side / 2, c.dy - side / 2)),
      Paint()..color = color ?? ZbTokens.sparkAmber,
    );
  }

  @override
  bool shouldRepaint(covariant StickerPainter old) =>
      old.size != size || old.tint != tint || old.rtl != rtl;
}

/* ══════════════════════════════════════════════════════════════════════
   THE PAW COIN — «بصمة»
   ══════════════════════════════════════════════════════════════════════ */

/// The currency, as an object: an amber coin with a paw struck into it.
///
/// It replaces the bare paw glyph everywhere a balance is printed, because a
/// number next to a footprint reads as a count of something, while a number
/// next to a coin reads as money you hold — which is exactly what the program
/// wants a paw to feel like.
class PawCoin extends StatelessWidget {
  const PawCoin({super.key, this.size = 20, this.muted = false});

  final double size;

  /// A spent/negative coin: same drawing, drained of colour.
  final bool muted;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: _PawCoinPainter(size: size, muted: muted),
        ),
      );
}

class _PawCoinPainter extends StickerPainter {
  const _PawCoinPainter({required super.size, required this.muted});

  final bool muted;

  static const List<Offset> _toes = [
    Offset(8.9, 10.5),
    Offset(10.85, 8.6),
    Offset(13.15, 8.6),
    Offset(15.1, 10.5),
  ];

  @override
  void draw(Canvas canvas) {
    final face = muted ? const Color(0xFFD9D2C3) : ZbTokens.amber;
    final edge = muted ? const Color(0xFFB9B2A3) : ZbTokens.orange;
    final stamp = muted ? ZbTokens.inkWarm.withValues(alpha: 0.5) : ZbTokens.inkWarm.withValues(alpha: 0.82);
    final l = line;

    // The edge shows below the face — the coin has thickness.
    canvas.stickerCircle(const Offset(12, 12.9), 10.2, edge, l);
    canvas.stickerCircle(const Offset(12, 11.4), 10.2, face, l);

    // Inner rim — the milled ring on a real coin.
    canvas.drawCircle(
      const Offset(12, 11.4),
      8.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = edge.withValues(alpha: 0.75),
    );

    // The strike.
    final paw = Paint()..color = stamp;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 13.5), width: 5.9, height: 4.5),
      paw,
    );
    for (final toe in _toes) {
      canvas.drawOval(Rect.fromCenter(center: toe, width: 2.5, height: 3.0), paw);
    }

    glossAt(canvas, const Offset(8.2, 6.4), w: 3.6, h: 1.8, alpha: muted ? 0.3 : 0.6);
  }

  @override
  bool shouldRepaint(covariant _PawCoinPainter old) =>
      super.shouldRepaint(old) || old.muted != muted;
}

/* ══════════════════════════════════════════════════════════════════════
   REWARD STICKERS
   ══════════════════════════════════════════════════════════════════════ */

/// The sticker for a reward kind: gift box, express parcel, delivery van, or
/// the coin for a paws prize. Unknown kinds draw the gift — the catalogue is
/// the owner's to extend and a present is the honest fallback.
class RewardSticker extends StatelessWidget {
  const RewardSticker({super.key, required this.kind, this.size = 56});

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == 'paws') return PawCoin(size: size);
    final rtl = context.isRtl;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: switch (kind) {
          'express_free' => _ExpressPainter(size: size, rtl: rtl),
          'free_delivery' => _VanPainter(size: size, rtl: rtl),
          _ => _GiftPainter(size: size),
        },
      ),
    );
  }
}

/// The hue behind each reward kind — one per kind, so a shelf is scannable
/// before a word is read. Gift = coral, express = the express orange, delivery
/// = brand teal, paws = amber.
Color rewardKindHue(BuildContext context, String kind) => switch (kind) {
      'express_free' => context.zb.tierExpress.fg,
      'free_delivery' => context.cs.primary,
      'paws' => context.isDark ? ZbTokens.amberOnDark : const Color(0xFFB57F0C),
      _ => context.zb.sale,
    };

/// The soft two-stop wash a reward sticker sits on.
LinearGradient rewardKindWash(BuildContext context, String kind) {
  final dark = context.isDark;
  final (Color a, Color b) = switch (kind) {
    'express_free' => dark
        ? (ZbTokens.expressBgDark, const Color(0xFF2A1810))
        : (const Color(0xFFFFE9D6), const Color(0xFFFFF5EC)),
    'free_delivery' => dark
        ? (ZbTokens.tealContainerDark, ZbTokens.tealContainerDarkEnd)
        : (ZbTokens.tealTint, ZbTokens.tealTintSoft),
    'paws' => dark
        ? (ZbTokens.amberContainerDark, ZbTokens.amberContainerDarkEnd)
        : (ZbTokens.amberTint, ZbTokens.amberTintSoft),
    _ => dark
        ? (ZbTokens.coralContainerDark, ZbTokens.coralContainerDarkEnd)
        : (ZbTokens.coralTint, ZbTokens.coralTintSoft),
  };
  return LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [a, b],
  );
}

/// The short name of a reward kind, for a chip above the title.
String rewardKindLabel(L l, String kind) => switch (kind) {
      'express_free' => l.rewardKindExpress,
      'free_delivery' => l.rewardKindDelivery,
      'paws' => l.rewardKindPaws,
      _ => l.rewardKindGift,
    };

/// A wrapped present: coral box, cream ribbon, a teal bow, and the sparkles
/// that the logo puts around anything worth having.
class _GiftPainter extends StickerPainter {
  const _GiftPainter({required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;
    const body = ZbTokens.logoCoral;
    const lid = Color(0xFFF08D5F);
    const ribbon = ZbTokens.creamLogo;
    const bow = ZbTokens.logoTeal;

    if (detailed) {
      sparkleAt(canvas, const Offset(3.2, 4.6), 3.6);
      sparkleAt(canvas, const Offset(21.2, 3.4), 4.2, color: ZbTokens.logoTeal);
      sparkleAt(canvas, const Offset(21.6, 9.6), 2.6);
    }

    // Body then lid, so the lid's outline sits over the body.
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(4.6, 11.2, 19.4, 21.2), const Radius.circular(2)),
      body,
      l,
    );
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(3.0, 7.6, 21.0, 12.2), const Radius.circular(1.8)),
      lid,
      l,
    );

    // Ribbon: one vertical band the full height of the box.
    canvas.drawRect(const Rect.fromLTRB(10.5, 7.9, 13.5, 20.9), Paint()..color = ribbon);
    canvas.drawLine(const Offset(10.5, 8.0), const Offset(10.5, 20.9), thin(0.9));
    canvas.drawLine(const Offset(13.5, 8.0), const Offset(13.5, 20.9), thin(0.9));

    // Bow: two loops and a knot.
    final loops = Path()
      ..moveTo(12, 7.4)
      ..cubicTo(9.4, 7.6, 6.6, 6.2, 7.6, 3.6)
      ..cubicTo(8.4, 1.8, 11.4, 3.4, 12, 7.4)
      ..close()
      ..moveTo(12, 7.4)
      ..cubicTo(14.6, 7.6, 17.4, 6.2, 16.4, 3.6)
      ..cubicTo(15.6, 1.8, 12.6, 3.4, 12, 7.4)
      ..close();
    canvas.sticker(loops, bow, l);
    canvas.stickerCircle(const Offset(12, 7.3), 1.35, bow, thin(1.0));

    glossAt(canvas, const Offset(7.2, 14.2), w: 2.6, h: 1.3, angle: -1.2, alpha: 0.42);
    glossAt(canvas, const Offset(8.6, 4.4), w: 1.6, h: 0.9, alpha: 0.6);
  }
}

/// A parcel in a hurry: the box leans into its direction of travel, three
/// speed trails behind it and a bolt on its face. Mirrors in Arabic so it
/// always runs *forward*.
class _ExpressPainter extends StickerPainter {
  const _ExpressPainter({required super.size, required bool rtl}) : _rtl = rtl;

  final bool _rtl;

  @override
  bool get rtl => _rtl;

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;
    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.logoTeal;

    trail.strokeWidth = 1.9;
    canvas.drawLine(const Offset(0.9, 9.2), const Offset(6.6, 9.2), trail);
    trail.strokeWidth = 1.6;
    canvas.drawLine(const Offset(2.4, 13.2), const Offset(6.4, 13.2), trail);
    trail.strokeWidth = 1.9;
    canvas.drawLine(const Offset(1.4, 17.2), const Offset(6.8, 17.2), trail);
    if (detailed) {
      canvas.drawCircle(const Offset(4.4, 5.4), 0.9, Paint()..color = ZbTokens.sparkAmber);
      canvas.drawCircle(const Offset(3.0, 21.0), 0.8, Paint()..color = ZbTokens.logoTeal.withValues(alpha: 0.8));
    }

    // The parcel — tilted a touch, so it is moving rather than parked.
    canvas.save();
    canvas.translate(15.0, 13.2);
    canvas.rotate(-0.09);
    canvas.translate(-15.0, -13.2);
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(8.2, 6.0, 21.8, 20.4), const Radius.circular(2.6)),
      ZbTokens.cardboard,
      l,
    );
    // Tape: the seam that says "box".
    canvas.drawRect(const Rect.fromLTRB(8.5, 9.4, 21.5, 11.6), Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.85));
    canvas.drawLine(const Offset(8.4, 9.4), const Offset(21.6, 9.4), thin(0.9));
    canvas.drawLine(const Offset(8.4, 11.6), const Offset(21.6, 11.6), thin(0.9));

    final bolt = Path()
      ..moveTo(16.4, 12.4)
      ..lineTo(12.4, 17.0)
      ..lineTo(14.9, 17.0)
      ..lineTo(13.9, 20.0)
      ..lineTo(18.0, 15.2)
      ..lineTo(15.5, 15.2)
      ..close();
    canvas.sticker(bolt, ZbTokens.amber, thin(1.0));
    glossAt(canvas, const Offset(11.2, 7.8), w: 2.4, h: 1.1, angle: -0.2, alpha: 0.5);
    canvas.restore();
  }
}

/// The delivery van: teal body, cream windscreen, two chunky wheels and the
/// logo's heart on the flank — it carries something loved.
class _VanPainter extends StickerPainter {
  const _VanPainter({required super.size, required bool rtl}) : _rtl = rtl;

  final bool _rtl;

  @override
  bool get rtl => _rtl;

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;
    const body = ZbTokens.logoTeal;

    // Road.
    canvas.drawLine(
      const Offset(2.0, 20.6),
      const Offset(22.0, 20.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2
        ..color = ZbTokens.inkWarm.withValues(alpha: 0.28),
    );

    // Cargo box + cab as one silhouette so the outline is continuous.
    final van = Path()
      ..moveTo(9.0, 6.4)
      ..lineTo(20.2, 6.4)
      ..quadraticBezierTo(22.0, 6.4, 22.0, 8.2)
      ..lineTo(22.0, 16.6)
      ..lineTo(2.2, 16.6)
      ..lineTo(2.2, 12.6)
      ..quadraticBezierTo(2.4, 10.2, 5.0, 9.6)
      ..lineTo(9.0, 9.4)
      ..close();
    canvas.sticker(van, body, l);
    // The seam between cab and box.
    canvas.drawLine(const Offset(9.0, 6.6), const Offset(9.0, 16.4), thin(1.0));

    // Windscreen.
    final glass = Path()
      ..moveTo(8.2, 10.0)
      ..lineTo(8.2, 13.8)
      ..lineTo(3.6, 13.8)
      ..quadraticBezierTo(3.8, 11.4, 5.6, 10.4)
      ..close();
    canvas.sticker(glass, ZbTokens.creamLogo, thin(1.0));

    // Heart on the flank — the cargo is somebody's friend.
    final heart = heartPath(const Rect.fromLTWH(12.6, 9.0, 5.6, 5.2));
    canvas.sticker(heart, ZbTokens.logoCoral, thin(0.9));

    // Wheels.
    for (final x in const [6.4, 17.6]) {
      canvas.stickerCircle(Offset(x, 17.6), 2.6, ZbTokens.inkWarm, l);
      canvas.drawCircle(Offset(x, 17.6), 1.0, Paint()..color = ZbTokens.creamLogo);
    }
    glossAt(canvas, const Offset(15.4, 7.8), w: 3.0, h: 1.1, angle: -0.1, alpha: 0.45);
  }
}

/* ══════════════════════════════════════════════════════════════════════
   MISSION STICKERS
   ══════════════════════════════════════════════════════════════════════ */

/// The sticker for a mission kind (`profile`, `welcome`, `frequency`,
/// `trial`, `category`). The server names kinds, not pictures, so a kind this
/// build has never seen gets the welcome box — a mission is always a small
/// present to unwrap.
class MissionSticker extends StatelessWidget {
  const MissionSticker({super.key, required this.kind, this.size = 52, this.done = false});

  final String kind;
  final double size;

  /// Adds the completed ribbon across the corner.
  final bool done;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: switch (kind) {
            'profile' => _ProfilePainter(size: size),
            'frequency' => _FrequencyPainter(size: size),
            'trial' => _TrialPainter(size: size, rtl: context.isRtl),
            'category' => _BowlPainter(size: size),
            _ => _WelcomePainter(size: size),
          },
        ),
      );
}

/// The hue of a mission kind, for its progress ring and reward chip.
Color missionKindHue(BuildContext context, String kind) => switch (kind) {
      'profile' => context.cs.primary,
      'frequency' => context.zb.sale,
      'trial' => context.isDark ? ZbTokens.amberOnDark : ZbTokens.amberDeep,
      'category' => context.isDark ? const Color(0xFF7ED39B) : ZbTokens.greenDeep,
      _ => context.zb.tierExpress.fg,
    };

/// An ID card with a pet's portrait and two lines — «أكمل ملف عائلتك».
class _ProfilePainter extends StickerPainter {
  const _ProfilePainter({required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(2.4, 5.2, 21.6, 19.4), const Radius.circular(2.4)),
      ZbTokens.creamLogo,
      l,
    );
    // Header band in teal, like a real membership card.
    canvas.drawPath(
      Path()
        ..moveTo(2.4, 8.6)
        ..lineTo(21.6, 8.6)
        ..lineTo(21.6, 7.6)
        ..quadraticBezierTo(21.6, 5.2, 19.2, 5.2)
        ..lineTo(4.8, 5.2)
        ..quadraticBezierTo(2.4, 5.2, 2.4, 7.6)
        ..close(),
      Paint()..color = ZbTokens.logoTeal,
    );
    canvas.drawLine(const Offset(2.4, 8.6), const Offset(21.6, 8.6), thin(1.0));

    // Portrait: a paw in a cardboard disc.
    canvas.stickerCircle(const Offset(7.4, 13.8), 3.3, ZbTokens.cardboard, thin(1.1));
    final paw = Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.8);
    canvas.drawOval(Rect.fromCenter(center: const Offset(7.4, 14.6), width: 2.4, height: 1.8), paw);
    for (final t in const [Offset(6.0, 13.2), Offset(7.0, 12.4), Offset(7.9, 12.4), Offset(8.8, 13.2)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.0, height: 1.2), paw);
    }

    // Two lines of "text": the fields still to fill.
    final text = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.55);
    canvas.drawLine(const Offset(12.4, 12.4), const Offset(18.8, 12.4), text);
    canvas.drawLine(const Offset(12.4, 15.4), const Offset(16.6, 15.4), text);
    // A heart sticker on the corner.
    canvas.sticker(heartPath(const Rect.fromLTWH(16.6, 15.6, 4.4, 4.0)), ZbTokens.logoCoral, thin(0.9));
    if (detailed) sparkleAt(canvas, const Offset(20.8, 3.6), 3.0);
  }
}

/// An open box with confetti — the first order from the app.
class _WelcomePainter extends StickerPainter {
  const _WelcomePainter({required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;
    // Confetti first, so the box lid draws over the bottom of it.
    if (detailed) {
      sparkleAt(canvas, const Offset(5.0, 4.2), 3.4);
      sparkleAt(canvas, const Offset(19.4, 3.6), 3.8, color: ZbTokens.logoTeal);
      canvas.drawCircle(const Offset(12.2, 2.6), 1.0, Paint()..color = ZbTokens.logoCoral);
      canvas.drawCircle(const Offset(8.6, 6.8), 0.8, Paint()..color = ZbTokens.logoTeal);
      canvas.drawCircle(const Offset(16.2, 6.4), 0.8, Paint()..color = ZbTokens.sparkAmber);
    }
    // The heart rising out of the box.
    canvas.sticker(heartPath(const Rect.fromLTWH(9.4, 4.6, 5.4, 5.0)), ZbTokens.logoCoral, thin(1.0));

    // Back flaps.
    final back = Path()
      ..moveTo(4.4, 11.0)
      ..lineTo(2.2, 7.6)
      ..lineTo(6.8, 7.0)
      ..lineTo(8.4, 11.0)
      ..close()
      ..moveTo(19.6, 11.0)
      ..lineTo(21.8, 7.6)
      ..lineTo(17.2, 7.0)
      ..lineTo(15.6, 11.0)
      ..close();
    canvas.sticker(back, const Color(0xFFC97F45), l);

    // Body.
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(4.4, 11.0, 19.6, 20.8), const Radius.circular(1.8)),
      ZbTokens.cardboard,
      l,
    );
    // Front flaps folded down.
    final front = Path()
      ..moveTo(4.4, 11.0)
      ..lineTo(3.2, 14.6)
      ..lineTo(9.0, 14.2)
      ..lineTo(9.6, 11.0)
      ..close()
      ..moveTo(19.6, 11.0)
      ..lineTo(20.8, 14.6)
      ..lineTo(15.0, 14.2)
      ..lineTo(14.4, 11.0)
      ..close();
    canvas.sticker(front, const Color(0xFFEAA66A), l);
    glossAt(canvas, const Offset(7.0, 17.6), w: 2.4, h: 1.0, angle: -1.3, alpha: 0.35);
  }
}

/// A calendar page with paws stamped on the days done.
class _FrequencyPainter extends StickerPainter {
  const _FrequencyPainter({required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(3.2, 5.4, 20.8, 20.8), const Radius.circular(2.4)),
      ZbTokens.creamLogo,
      l,
    );
    // Header.
    canvas.drawPath(
      Path()
        ..moveTo(3.2, 9.8)
        ..lineTo(20.8, 9.8)
        ..lineTo(20.8, 7.8)
        ..quadraticBezierTo(20.8, 5.4, 18.4, 5.4)
        ..lineTo(5.6, 5.4)
        ..quadraticBezierTo(3.2, 5.4, 3.2, 7.8)
        ..close(),
      Paint()..color = ZbTokens.logoCoral,
    );
    canvas.drawLine(const Offset(3.2, 9.8), const Offset(20.8, 9.8), thin(1.0));
    // Rings.
    for (final x in const [7.6, 16.4]) {
      canvas.drawLine(Offset(x, 3.4), Offset(x, 7.2), strokePaint(width: 1.6));
    }
    // Days: two stamped paws and one waiting.
    final stamp = Paint()..color = ZbTokens.logoTeal;
    void pawAt(Offset c, Paint p) {
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + 0.7), width: 2.6, height: 2.0), p);
      for (final t in [Offset(c.dx - 1.4, c.dy - 0.6), Offset(c.dx - 0.5, c.dy - 1.3), Offset(c.dx + 0.5, c.dy - 1.3), Offset(c.dx + 1.4, c.dy - 0.6)]) {
        canvas.drawOval(Rect.fromCenter(center: t, width: 1.0, height: 1.2), p);
      }
    }

    pawAt(const Offset(7.4, 13.6), stamp);
    pawAt(const Offset(12.0, 13.6), stamp);
    canvas.drawCircle(
      const Offset(16.6, 13.6),
      1.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = ZbTokens.inkWarm.withValues(alpha: 0.35),
    );
    pawAt(const Offset(7.4, 17.8), Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.16));
    pawAt(const Offset(12.0, 17.8), Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.16));
    pawAt(const Offset(16.6, 17.8), Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.16));
  }
}

/// A shopping bag with a star tag — try something new.
class _TrialPainter extends StickerPainter {
  const _TrialPainter({required super.size, required bool rtl}) : _rtl = rtl;

  final bool _rtl;

  @override
  bool get rtl => _rtl;

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;
    // Handles behind the bag.
    final handle = Path()
      ..moveTo(8.6, 9.0)
      ..cubicTo(8.4, 3.4, 15.6, 3.4, 15.4, 9.0);
    canvas.drawPath(handle, strokePaint(width: 1.6));

    final bag = Path()
      ..moveTo(5.0, 8.6)
      ..lineTo(19.0, 8.6)
      ..lineTo(20.4, 19.0)
      ..quadraticBezierTo(20.6, 21.0, 18.6, 21.0)
      ..lineTo(5.4, 21.0)
      ..quadraticBezierTo(3.4, 21.0, 3.6, 19.0)
      ..close();
    canvas.sticker(bag, ZbTokens.logoTeal, l);
    // Paw on the bag.
    final paw = Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.92);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12, 15.8), width: 3.6, height: 2.8), paw);
    for (final t in const [Offset(10.0, 13.6), Offset(11.2, 12.5), Offset(12.8, 12.5), Offset(14.0, 13.6)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.4, height: 1.7), paw);
    }
    glossAt(canvas, const Offset(6.8, 11.2), w: 2.2, h: 1.0, angle: -1.2, alpha: 0.35);

    // The star tag on the corner.
    final star = _starPath(const Offset(18.6, 7.2), 4.2, 1.9);
    canvas.sticker(star, ZbTokens.amber, thin(1.0));
  }
}

/// A food bowl with kibble — the species category mission.
class _BowlPainter extends StickerPainter {
  const _BowlPainter({required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;
    // Kibble pile behind the rim.
    for (final (c, col) in const [
      (Offset(9.0, 10.6), ZbTokens.cardboard),
      (Offset(12.2, 9.2), Color(0xFFC97F45)),
      (Offset(15.2, 10.6), ZbTokens.cardboard),
      (Offset(10.8, 8.0), ZbTokens.cardboard),
      (Offset(13.8, 7.6), Color(0xFFC97F45)),
    ]) {
      canvas.stickerCircle(c, 1.9, col, thin(1.0));
    }
    // Bowl: a wide rim ellipse and a rounded base.
    final base = Path()
      ..moveTo(3.4, 12.6)
      ..lineTo(20.6, 12.6)
      ..quadraticBezierTo(20.0, 20.6, 12.0, 20.8)
      ..quadraticBezierTo(4.0, 20.6, 3.4, 12.6)
      ..close();
    canvas.sticker(base, ZbTokens.logoTeal, l);
    canvas.stickerOval(
      const Rect.fromLTRB(2.6, 10.8, 21.4, 14.4),
      const Color(0xFF7FC3BC),
      l,
    );
    // A paw on the bowl.
    final paw = Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.92);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12, 17.4), width: 2.8, height: 2.1), paw);
    for (final t in const [Offset(10.5, 15.8), Offset(11.4, 15.0), Offset(12.6, 15.0), Offset(13.5, 15.8)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.1, height: 1.3), paw);
    }
    if (detailed) sparkleAt(canvas, const Offset(19.4, 6.2), 3.2);
  }
}

/// A rounded five-point star.
Path _starPath(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 5;
    final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/* ══════════════════════════════════════════════════════════════════════
   SMALL MARKS — lock, check, book, bulb, clock, foil
   ══════════════════════════════════════════════════════════════════════ */

enum FamilyMark { lock, check, book, bulb, clock, family, plus, bowl, repeat, share, cake, tag, moon }

/// One small painted mark. These replace the Material outlines the program
/// used to wear: a lock with a keyhole rather than a wire padlock, a check on
/// a badge rather than a floating tick.
class FamilyMarkIcon extends StatelessWidget {
  const FamilyMarkIcon(this.mark, {super.key, this.size = 20, this.color});

  final FamilyMark mark;
  final double size;

  /// The body colour. Defaults per mark.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (mark == FamilyMark.plus) {
      return ZbIcon(ZbIconKind.plus, size: size, ink: color ?? context.cs.primary);
    }
    if (mark == FamilyMark.family) {
      return ZbIcon(ZbIconKind.paw, size: size, fill: 1, tint: color);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(mark: mark, size: size, tint: color),
      ),
    );
  }
}

class _MarkPainter extends StickerPainter {
  const _MarkPainter({required this.mark, required super.size, super.tint});

  final FamilyMark mark;

  @override
  void draw(Canvas canvas) {
    switch (mark) {
      case FamilyMark.lock:
        _lock(canvas);
      case FamilyMark.check:
        _check(canvas);
      case FamilyMark.book:
        _book(canvas);
      case FamilyMark.bulb:
        _bulb(canvas);
      case FamilyMark.clock:
        _clock(canvas);
      case FamilyMark.bowl:
        _bowl(canvas);
      case FamilyMark.repeat:
        _repeat(canvas);
      case FamilyMark.share:
        _share(canvas);
      case FamilyMark.cake:
        _cake(canvas);
      case FamilyMark.tag:
        _tag(canvas);
      case FamilyMark.moon:
        _moon(canvas);
      case FamilyMark.family:
      case FamilyMark.plus:
        break;
    }
  }

  /// The food bowl — the gauge's own mark: a bowl with kibble heaped in it.
  void _bowl(Canvas canvas) {
    final l = line;
    final body = tint ?? ZbTokens.logoTeal;
    // Kibble heap first (behind the rim).
    final kibble = Paint()..color = ZbTokens.cardboard;
    for (final k in const [Offset(9.0, 9.6), Offset(12.0, 8.4), Offset(15.0, 9.6), Offset(10.6, 11.0), Offset(13.4, 11.0)]) {
      canvas.drawCircle(k, 1.7, kibble);
      canvas.drawCircle(k, 1.7, thin(0.9));
    }
    // Bowl body.
    canvas.sticker(
      Path()
        ..moveTo(3.6, 11.6)
        ..lineTo(20.4, 11.6)
        ..cubicTo(20.4, 16.4, 17.6, 20.2, 12.0, 20.2)
        ..cubicTo(6.4, 20.2, 3.6, 16.4, 3.6, 11.6)
        ..close(),
      body,
      l,
    );
    // Rim.
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(2.8, 10.4, 21.2, 13.2), const Radius.circular(1.4)),
      ZbTokens.creamLogo,
      l,
    );
    // A tiny paw on the bowl, the way the real ones have.
    final paw = Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12, 16.9), width: 2.6, height: 1.9), paw);
    for (final t in const [Offset(10.5, 15.3), Offset(11.4, 14.5), Offset(12.6, 14.5), Offset(13.5, 15.3)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.0, height: 1.2), paw);
    }
    glossAt(canvas, const Offset(6.4, 15.0), w: 2.4, h: 1.0, angle: -0.9, alpha: 0.35);
  }

  /// Two arrows chasing each other on a disc — «كل شهر».
  void _repeat(Canvas canvas) {
    final body = tint ?? ZbTokens.logoCoral;
    canvas.stickerCircle(const Offset(12, 12), 9.6, body, line);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.creamLogo;
    canvas.drawArc(const Rect.fromLTRB(6.6, 6.6, 17.4, 17.4), -2.6, 2.2, false, ink);
    canvas.drawArc(const Rect.fromLTRB(6.6, 6.6, 17.4, 17.4), 0.55, 2.2, false, ink);
    final head = Paint()..color = ZbTokens.creamLogo;
    canvas.drawPath(Path()..moveTo(15.2, 5.4)..lineTo(17.8, 8.6)..lineTo(14.0, 9.0)..close(), head);
    canvas.drawPath(Path()..moveTo(8.8, 18.6)..lineTo(6.2, 15.4)..lineTo(10.0, 15.0)..close(), head);
    glossAt(canvas, const Offset(8.2, 6.8), w: 3.0, h: 1.4, alpha: 0.35);
  }

  /// Three dots joined — the invitation going out.
  void _share(Canvas canvas) {
    final body = tint ?? ZbTokens.logoTeal;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.7);
    canvas.drawLine(const Offset(8.4, 12.0), const Offset(15.8, 7.4), stroke);
    canvas.drawLine(const Offset(8.4, 12.0), const Offset(15.8, 16.6), stroke);
    canvas.stickerCircle(const Offset(6.6, 12.0), 3.4, body, line);
    canvas.stickerCircle(const Offset(17.4, 6.4), 3.2, ZbTokens.creamLogo, line);
    canvas.stickerCircle(const Offset(17.4, 17.6), 3.2, ZbTokens.logoCoral, line);
    glossAt(canvas, const Offset(5.4, 10.6), w: 1.6, h: 0.8, alpha: 0.5);
  }

  /// A slice of cake with one candle, for the birthday week.
  void _cake(Canvas canvas) {
    final l = line;
    final body = tint ?? ZbTokens.logoCoral;
    // Candle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(11.1, 4.6, 12.9, 9.6), const Radius.circular(0.8)),
      Paint()..color = ZbTokens.logoTeal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(11.1, 4.6, 12.9, 9.6), const Radius.circular(0.8)),
      thin(0.9),
    );
    canvas.sticker(
      Path()
        ..moveTo(12.0, 1.6)
        ..quadraticBezierTo(14.0, 3.2, 12.0, 4.6)
        ..quadraticBezierTo(10.0, 3.2, 12.0, 1.6)
        ..close(),
      ZbTokens.sparkAmber,
      thin(0.8),
    );
    // Cake body: two layers.
    canvas.stickerRRect(
      RRect.fromRectAndCorners(const Rect.fromLTRB(4.0, 9.4, 20.0, 20.8), bottomLeft: const Radius.circular(2.4), bottomRight: const Radius.circular(2.4), topLeft: const Radius.circular(1.6), topRight: const Radius.circular(1.6)),
      body,
      l,
    );
    // Icing drips.
    final icing = Paint()..color = ZbTokens.creamLogo;
    canvas.drawPath(
      Path()
        ..moveTo(4.0, 11.4)
        ..lineTo(20.0, 11.4)
        ..lineTo(20.0, 12.6)
        ..cubicTo(18.6, 12.6, 18.6, 14.6, 17.2, 14.6)
        ..cubicTo(15.8, 14.6, 15.8, 12.6, 14.4, 12.6)
        ..cubicTo(13.0, 12.6, 13.0, 15.0, 11.6, 15.0)
        ..cubicTo(10.2, 15.0, 10.2, 12.6, 8.8, 12.6)
        ..cubicTo(7.4, 12.6, 7.4, 14.2, 6.0, 14.2)
        ..cubicTo(5.2, 14.2, 4.6, 13.2, 4.0, 12.6)
        ..close(),
      icing,
    );
    canvas.drawLine(const Offset(4.4, 16.8), const Offset(19.6, 16.8), thin(0.9));
    glossAt(canvas, const Offset(6.4, 18.6), w: 2.0, h: 0.8, angle: -0.6, alpha: 0.3);
  }

  /// A price tag with a paw hole — the brand card.
  void _tag(Canvas canvas) {
    final body = tint ?? ZbTokens.amber;
    canvas.sticker(
      Path()
        ..moveTo(3.6, 13.2)
        ..lineTo(11.0, 5.8)
        ..lineTo(19.6, 4.0)
        ..lineTo(20.2, 4.6)
        ..lineTo(18.4, 13.2)
        ..lineTo(11.0, 20.6)
        ..close(),
      body,
      line,
    );
    canvas.drawCircle(const Offset(16.4, 7.8), 1.6, Paint()..color = ZbTokens.creamLogo);
    canvas.drawCircle(const Offset(16.4, 7.8), 1.6, thin(0.9));
    // A stamp mark on the tag.
    final paw = Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.55);
    canvas.drawOval(Rect.fromCenter(center: const Offset(10.6, 13.6), width: 2.6, height: 2.0), paw);
    for (final t in const [Offset(9.0, 12.0), Offset(9.9, 11.1), Offset(11.3, 11.1), Offset(12.2, 12.0)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.0, height: 1.2), paw);
    }
    glossAt(canvas, const Offset(7.2, 12.4), w: 2.2, h: 0.9, angle: -0.8, alpha: 0.4);
  }

  /// A crescent — «عندي كفاية», snooze.
  void _moon(Canvas canvas) {
    final body = tint ?? ZbTokens.amber;
    final moon = Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.6));
    final bite = Path()..addOval(Rect.fromCircle(center: const Offset(15.4, 9.6), radius: 7.2));
    canvas.sticker(Path.combine(PathOperation.difference, moon, bite), body, line);
    if (detailed) {
      sparkleAt(canvas, const Offset(18.4, 6.4), 2.6, color: ZbTokens.logoTeal);
    }
    glossAt(canvas, const Offset(7.4, 9.6), w: 2.2, h: 1.0, angle: -1.1, alpha: 0.45);
  }

  void _lock(Canvas canvas) {
    final l = line;
    final body = tint ?? const Color(0xFFB9B2A3);
    canvas.drawPath(
      Path()
        ..moveTo(7.4, 11.0)
        ..lineTo(7.4, 8.4)
        ..cubicTo(7.4, 2.4, 16.6, 2.4, 16.6, 8.4)
        ..lineTo(16.6, 11.0),
      strokePaint(width: 2.0),
    );
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(4.6, 10.4, 19.4, 21.0), const Radius.circular(2.8)),
      body,
      l,
    );
    canvas.drawCircle(const Offset(12, 14.6), 1.6, Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.75));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(11.2, 15.2, 12.8, 18.2), const Radius.circular(0.8)),
      Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.75),
    );
    glossAt(canvas, const Offset(7.4, 13.0), w: 2.0, h: 0.9, angle: -1.3, alpha: 0.4);
  }

  void _check(Canvas canvas) {
    final body = tint ?? ZbTokens.success;
    canvas.stickerCircle(const Offset(12, 12), 9.6, body, line);
    canvas.drawPath(
      Path()
        ..moveTo(7.6, 12.4)
        ..lineTo(10.8, 15.6)
        ..lineTo(16.6, 8.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ZbTokens.creamLogo,
    );
    glossAt(canvas, const Offset(8.2, 6.8), w: 3.0, h: 1.4, alpha: 0.4);
  }

  void _book(Canvas canvas) {
    final l = line;
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(4.4, 3.4, 19.6, 20.6), const Radius.circular(2.2)),
      ZbTokens.creamLogo,
      l,
    );
    // Spine.
    canvas.drawPath(
      Path()
        ..moveTo(4.4, 5.6)
        ..quadraticBezierTo(4.4, 3.4, 6.6, 3.4)
        ..lineTo(8.6, 3.4)
        ..lineTo(8.6, 20.6)
        ..lineTo(6.6, 20.6)
        ..quadraticBezierTo(4.4, 20.6, 4.4, 18.4)
        ..close(),
      Paint()..color = tint ?? ZbTokens.logoTeal,
    );
    canvas.drawLine(const Offset(8.6, 3.6), const Offset(8.6, 20.4), thin(1.0));
    final text = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.5);
    canvas.drawLine(const Offset(11.2, 8.0), const Offset(16.8, 8.0), text);
    canvas.drawLine(const Offset(11.2, 11.2), const Offset(16.8, 11.2), text);
    canvas.drawLine(const Offset(11.2, 14.4), const Offset(14.6, 14.4), text);
    // The stamp on the last page.
    final paw = Paint()..color = ZbTokens.logoCoral;
    canvas.drawOval(Rect.fromCenter(center: const Offset(15.4, 17.9), width: 2.4, height: 1.8), paw);
    for (final t in const [Offset(14.1, 16.6), Offset(14.9, 15.9), Offset(15.9, 15.9), Offset(16.7, 16.6)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 0.9, height: 1.1), paw);
    }
  }

  void _bulb(Canvas canvas) {
    final l = line;
    if (detailed) {
      sparkleAt(canvas, const Offset(4.0, 5.0), 3.2);
      sparkleAt(canvas, const Offset(20.4, 4.6), 2.8, color: ZbTokens.logoTeal);
    }
    final bulb = Path()
      ..moveTo(8.8, 15.6)
      ..cubicTo(6.6, 14.2, 5.0, 12.2, 5.0, 9.6)
      ..cubicTo(5.0, 5.6, 8.2, 2.8, 12.0, 2.8)
      ..cubicTo(15.8, 2.8, 19.0, 5.6, 19.0, 9.6)
      ..cubicTo(19.0, 12.2, 17.4, 14.2, 15.2, 15.6)
      ..close();
    canvas.sticker(bulb, tint ?? ZbTokens.amber, l);
    // The filament, drawn as a tiny paw — it is the program's idea, after all.
    final paw = Paint()..color = ZbTokens.inkWarm.withValues(alpha: 0.7);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12, 11.2), width: 3.0, height: 2.3), paw);
    for (final t in const [Offset(10.3, 9.4), Offset(11.3, 8.5), Offset(12.7, 8.5), Offset(13.7, 9.4)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.2, height: 1.4), paw);
    }
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(9.0, 15.4, 15.0, 19.2), const Radius.circular(1.4)),
      ZbTokens.creamLogo,
      l,
    );
    canvas.drawLine(const Offset(9.4, 17.3), const Offset(14.6, 17.3), thin(0.9));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(10.2, 19.2, 13.8, 21.0), const Radius.circular(0.9)),
      Paint()..color = ZbTokens.inkWarm,
    );
    glossAt(canvas, const Offset(8.6, 6.8), w: 2.6, h: 1.3, alpha: 0.55);
  }

  void _clock(Canvas canvas) {
    canvas.stickerCircle(const Offset(12, 12.4), 9.4, tint ?? ZbTokens.creamLogo, line);
    canvas.drawPath(
      Path()
        ..moveTo(12, 7.4)
        ..lineTo(12, 12.6)
        ..lineTo(15.4, 14.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ZbTokens.inkWarm,
    );
    canvas.drawCircle(const Offset(12, 12.6), 1.0, Paint()..color = ZbTokens.logoCoral);
    glossAt(canvas, const Offset(8.4, 7.6), w: 2.8, h: 1.3, alpha: 0.5);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      super.shouldRepaint(old) || old.mark != mark;
}

/* ══════════════════════════════════════════════════════════════════════
   SURFACES — the paw-print pattern, progress ring, tier ladder
   ══════════════════════════════════════════════════════════════════════ */

/// Scattered paw prints at a whisper of opacity — the texture of a
/// membership card. Deterministic, so a card never re-shuffles under a
/// customer's thumb.
class PawPattern extends StatelessWidget {
  const PawPattern({super.key, this.color = Colors.white, this.opacity = 0.10, this.scale = 1});

  final Color color;
  final double opacity;
  final double scale;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _PawPatternPainter(color.withValues(alpha: opacity), scale),
          size: Size.infinite,
        ),
      );
}

class _PawPatternPainter extends CustomPainter {
  const _PawPatternPainter(this.color, this.scale);

  final Color color;
  final double scale;

  // (dx, dy) as fractions of the box, size in points, rotation in radians.
  static const List<(double, double, double, double)> _prints = [
    (0.06, 0.18, 30, -0.4),
    (0.22, 0.78, 22, 0.5),
    (0.40, 0.10, 18, 0.2),
    (0.55, 0.62, 34, -0.7),
    (0.72, 0.16, 24, 0.9),
    (0.86, 0.74, 28, -0.2),
    (0.94, 0.36, 16, 0.4),
    (0.34, 0.44, 14, 1.1),
    (0.66, 0.92, 18, 0.3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (fx, fy, s, rot) in _prints) {
      final side = s * scale;
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy);
      canvas.rotate(rot);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, side * 0.16), width: side * 0.52, height: side * 0.42), paint);
      for (final (tx, ty) in const [(-0.28, -0.12), (-0.1, -0.26), (0.1, -0.26), (0.28, -0.12)]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(side * tx, side * ty), width: side * 0.2, height: side * 0.24),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PawPatternPainter old) => old.color != color || old.scale != scale;
}

/// A ring that draws itself to [value], with whatever sits in the middle.
///
/// Used for a mission's progress and for the family card's "how far to the
/// next tier" — a ring reads as a *fraction* at a glance where a bar reads as
/// a length, and every number in this program is a fraction of a target.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 52,
    this.stroke = 5,
    this.track,
    this.child,
    this.animate = true,
  });

  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Color? track;
  final Widget? child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final trackColor = track ?? context.cs.onSurface.withValues(alpha: context.isDark ? 0.14 : 0.08);
    final target = value.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : target, end: target),
        duration: context.motion(const Duration(milliseconds: 720)),
        curve: Motion.emphasized,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, color, trackColor, stroke, context.isRtl),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, this.color, this.track, this.stroke, this.rtl);

  final double value;
  final Color color;
  final Color track;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    // Starts at 12 o'clock and runs with the reading direction.
    final sweep = math.pi * 2 * value * (rtl ? -1 : 1);
    canvas.drawArc(
      r,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke || old.rtl != rtl;
}

/// The five rungs of the ladder as the store defines them.
///
/// The names and hues are the store's own constants (the account page on the
/// web paints the same ones); the app keeps a copy so a perk can say «من
/// مستوى ذهبي» even when the server only sends the key.
@immutable
class TierRung {
  const TierRung(this.key, this.nameAr, this.nameEn, this.c1, this.c2);

  final String key;
  final String nameAr;
  final String nameEn;
  final Color c1;
  final Color c2;

  String name(String locale) => locale == 'ar' ? nameAr : nameEn;

  static const List<TierRung> ladder = [
    TierRung('new', 'بداية الرحلة', 'Start', Color(0xFF8FB9A8), Color(0xFF6FA08D)),
    TierRung('friend', 'صديق', 'Friend', Color(0xFF5FB3B2), Color(0xFF429D9C)),
    TierRung('star', 'مميّز', 'Star', Color(0xFFE8A765), Color(0xFFD48644)),
    TierRung('gold', 'ذهبي', 'Gold', Color(0xFFE0B341), Color(0xFFC99320)),
    TierRung('amb', 'سفير', 'Ambassador', Color(0xFFE07A63), Color(0xFFD46856)),
  ];

  static TierRung? byKey(String? key) {
    for (final rung in ladder) {
      if (rung.key == key) return rung;
    }
    return null;
  }

  static int rank(String? key) {
    for (var i = 0; i < ladder.length; i++) {
      if (ladder[i].key == key) return i;
    }
    return 0;
  }
}

/// The ladder drawn as five rungs joined by a line that fills up to where
/// this customer stands. The current rung is the large one.
class TierLadder extends StatelessWidget {
  const TierLadder({
    super.key,
    required this.currentKey,
    required this.progressToNext,
    this.onColored = false,
  });

  final String currentKey;

  /// 0..1 within the current rung, drawn as the partial line to the next.
  final double progressToNext;

  /// Drawn on a coloured ground (white marks) rather than on the surface.
  final bool onColored;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final rank = TierRung.rank(currentKey);
    final cs = context.cs;
    final lineColor = onColored ? Colors.white : cs.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final n = TierRung.ladder.length;
        final w = constraints.maxWidth;
        final slot = w / n;
        return SizedBox(
          height: 54,
          child: Stack(
            children: [
              // The rail.
              Positioned(
                top: 13,
                left: slot / 2,
                right: slot / 2,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: onColored ? 0.28 : 0.10),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // The part already climbed, plus the partial step.
              PositionedDirectional(
                top: 13,
                start: slot / 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (rank + progressToNext.clamp(0.0, 1.0)) * slot),
                  duration: context.motion(const Duration(milliseconds: 820)),
                  curve: Motion.emphasized,
                  builder: (context, v, _) => Container(
                    height: 3,
                    width: v.clamp(0.0, (n - 1) * slot),
                    decoration: BoxDecoration(
                      color: onColored ? Colors.white : TierRung.ladder[rank].c2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < n; i++)
                PositionedDirectional(
                  start: i * slot,
                  top: 0,
                  width: slot,
                  child: _Rung(
                    rung: TierRung.ladder[i],
                    state: i < rank ? _RungState.climbed : (i == rank ? _RungState.current : _RungState.ahead),
                    label: TierRung.ladder[i].name(locale),
                    onColored: onColored,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _RungState { climbed, current, ahead }

class _Rung extends StatelessWidget {
  const _Rung({required this.rung, required this.state, required this.label, required this.onColored});

  final TierRung rung;
  final _RungState state;
  final String label;
  final bool onColored;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final current = state == _RungState.current;
    final ahead = state == _RungState.ahead;
    final dot = current ? 22.0 : 12.0;
    final fill = switch (state) {
      _RungState.current => onColored ? Colors.white : rung.c2,
      _RungState.climbed => onColored ? Colors.white.withValues(alpha: 0.92) : rung.c2,
      _RungState.ahead => onColored ? Colors.white.withValues(alpha: 0.30) : cs.surfaceContainerHighest,
    };
    final text = onColored
        ? Colors.white.withValues(alpha: ahead ? 0.62 : 1)
        : (ahead ? cs.onSurfaceVariant : cs.onSurface);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 29,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(Motion.select),
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: current
                    ? Border.all(color: onColored ? rung.c2 : Colors.white, width: 3)
                    : null,
                boxShadow: current
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: current
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: onColored ? rung.c2 : Colors.white, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.tt.labelSmall?.copyWith(
            fontSize: 10.5,
            color: text,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A number that counts up to its value the first time it is shown — the
/// wallet balance, a prize. Tabular, so the width never jitters while it runs.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.format, this.style, this.duration});

  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration? duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: context.motion(duration ?? const Duration(milliseconds: 900)),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          format(v.round()),
          style: (style ?? context.tt.headlineLarge)?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}
