import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/painters/icon_painter.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../data/pet_models.dart';

/// The coat a species is drawn in, and the wash its portrait sits on.
///
/// These are the logo's own warm colours rather than the UI palette: an avatar
/// is a character, not a control. The cat is the mascot's ginger, the dog the
/// mascot's cream with brown ears, and each of the others gets one hue that is
/// unmistakably theirs on a shelf of seven.
@immutable
class SpeciesArt {
  const SpeciesArt({
    required this.coat,
    required this.shade,
    required this.accent,
    required this.well,
  });

  /// The main fill.
  final Color coat;

  /// Ears, patches, fins — one step deeper than [coat].
  final Color shade;

  /// The one saturated detail: a beak, a nose, a tongue.
  final Color accent;

  /// The light disc behind the portrait (light theme).
  final Color well;

  static SpeciesArt of(PetSpecies species) => switch (species) {
        PetSpecies.cat => const SpeciesArt(
            coat: ZbTokens.cardboard,
            shade: Color(0xFFC97F45),
            accent: ZbTokens.logoCoral,
            well: Color(0xFFFBE7D4),
          ),
        PetSpecies.dog => const SpeciesArt(
            coat: Color(0xFFF3E4CB),
            shade: Color(0xFFC97F45),
            accent: ZbTokens.logoCoral,
            well: Color(0xFFF7E3D3),
          ),
        PetSpecies.bird => const SpeciesArt(
            coat: ZbTokens.amber,
            shade: ZbTokens.orange,
            accent: ZbTokens.logoCoral,
            well: Color(0xFFFBEBCF),
          ),
        PetSpecies.fish => const SpeciesArt(
            coat: ZbTokens.logoTeal,
            shade: ZbTokens.tealDark,
            accent: ZbTokens.amber,
            well: ZbTokens.tealTint,
          ),
        PetSpecies.small => const SpeciesArt(
            coat: Color(0xFFF7DDC7),
            shade: Color(0xFFE2B893),
            accent: Color(0xFFE9908A),
            well: Color(0xFFFDF1EC),
          ),
        PetSpecies.reptile => const SpeciesArt(
            coat: Color(0xFF86C46E),
            shade: Color(0xFF5E9C4C),
            accent: ZbTokens.logoCoral,
            well: Color(0xFFDDF0E3),
          ),
        PetSpecies.other => const SpeciesArt(
            coat: ZbTokens.logoCoral,
            shade: Color(0xFFC85F33),
            accent: ZbTokens.creamLogo,
            well: Color(0xFFFBE3DC),
          ),
      };
}

/// A drawn portrait for one species, in the mascot's hand — or the pet's own
/// photo when one is on file.
///
/// No emoji: an emoji is the OS's drawing, and it lands in the middle of a
/// screen that is otherwise entirely ours. These faces share the closed happy
/// eyes, the blush and the gloss of the two animals on the box, so a customer's
/// cat is visibly a cousin of the one in the logo.
class SpeciesAvatar extends StatelessWidget {
  const SpeciesAvatar({
    super.key,
    required this.species,
    this.size = 56,
    this.selected = false,
    this.showWell = true,
    this.photoUrl,
    this.ring,
  });

  final PetSpecies species;
  final double size;

  /// Rings the well in the species' own colour — the picker's selected state.
  final bool selected;

  /// False drops the tinted disc and draws the portrait alone, for a card
  /// that already has a surface of its own.
  final bool showWell;

  /// The pet's photo, shown instead of the drawing when present.
  final String? photoUrl;

  /// A solid ring colour (a white ring on a coloured card, for instance).
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final art = SpeciesArt.of(species);
    final photo = photoUrl;
    final glyph = photo != null && photo.isNotEmpty
        ? ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: ZbImage(url: photo, fit: BoxFit.cover),
            ),
          )
        : SizedBox.square(
            dimension: size * 0.80,
            child: CustomPaint(
              size: Size.square(size * 0.80),
              painter: _painter(art, size * 0.80),
            ),
          );

    if (!showWell) return SizedBox.square(dimension: size, child: Center(child: glyph));

    final dark = context.isDark;
    final ringColor = ring ?? (selected ? art.shade : art.coat.withValues(alpha: dark ? 0.45 : 0.55));
    final ringWidth = ring != null ? 3.0 : (selected ? 2.4 : 1.4);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: dark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [art.well, Color.lerp(art.well, Colors.white, 0.45)!],
              ),
        color: dark ? art.coat.withValues(alpha: 0.22) : null,
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: selected
            ? [BoxShadow(color: art.shade.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: glyph,
    );
  }

  ZbIconPainter _painter(SpeciesArt art, double side) => switch (species) {
        PetSpecies.cat => _CatPainter(art: art, size: side),
        PetSpecies.dog => _DogPainter(art: art, size: side),
        PetSpecies.bird => _BirdPainter(art: art, size: side),
        PetSpecies.fish => _FishPainter(art: art, size: side),
        PetSpecies.small => _SmallPainter(art: art, size: side),
        PetSpecies.reptile => _ReptilePainter(art: art, size: side),
        PetSpecies.other => _OtherPainter(art: art, size: side),
      };
}

/// Shared plumbing for the seven portraits: the sticker stroke, the mascot's
/// closed happy eyes, its blush, and the gloss — the family resemblance.
abstract class _SpeciesPainter extends StickerPainter {
  const _SpeciesPainter({required this.art, required super.size});

  final SpeciesArt art;

  /// The mascot's eyes: two arcs, closed in a smile.
  void happyEyes(Canvas canvas, {required double y, double spread = 3.4, double w = 2.9, double lift = 2.2}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kStickerStroke
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm;
    for (final cx in [12 - spread, 12 + spread]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - w / 2, y)
          ..quadraticBezierTo(cx, y - lift, cx + w / 2, y),
        p,
      );
    }
  }

  /// A round open eye with a cream white and a gloss — for the side-facing
  /// animals, whose one visible eye has to carry the whole expression.
  void roundEye(Canvas canvas, Offset c, {double r = 2.3}) {
    canvas.stickerCircle(c, r, ZbTokens.creamLogo, thin(1.0));
    canvas.drawCircle(Offset(c.dx + r * 0.08, c.dy + r * 0.1), r * 0.58, Paint()..color = ZbTokens.inkWarm);
    canvas.drawCircle(Offset(c.dx - r * 0.18, c.dy - r * 0.28), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  /// The blush the logo's animals wear.
  void blush(Canvas canvas, {required double y, double spread = 5.6, double w = 3.2, double alpha = 0.34}) {
    if (!detailed) return;
    final paint = Paint()..color = ZbTokens.logoCoral.withValues(alpha: alpha);
    canvas.drawOval(Rect.fromCenter(center: Offset(12 - spread, y), width: w, height: w * 0.58), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(12 + spread, y), width: w, height: w * 0.58), paint);
  }

  /// The «ω» mouth under a small nose.
  void catMouth(Canvas canvas, Offset nose, {double reach = 1.6, double drop = 1.5}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm;
    canvas.drawPath(
      Path()
        ..moveTo(nose.dx, nose.dy)
        ..quadraticBezierTo(nose.dx - reach * 0.7, nose.dy + drop, nose.dx - reach, nose.dy + drop * 0.35)
        ..moveTo(nose.dx, nose.dy)
        ..quadraticBezierTo(nose.dx + reach * 0.7, nose.dy + drop, nose.dx + reach, nose.dy + drop * 0.35),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeciesPainter old) =>
      super.shouldRepaint(old) || old.art.coat != art.coat;
}

/// The mascot's cat: pricked ears with pink insides, three forehead stripes,
/// a cream muzzle, whiskers.
class _CatPainter extends _SpeciesPainter {
  const _CatPainter({required super.art, required super.size});

  @override
  void draw(Canvas canvas) {
    final l = line;

    final earL = Path()
      ..moveTo(4.0, 10.8)
      ..lineTo(4.6, 3.6)
      ..quadraticBezierTo(4.8, 2.6, 5.7, 3.2)
      ..lineTo(11.0, 6.6)
      ..close();
    final earR = Path()
      ..moveTo(20.0, 10.8)
      ..lineTo(19.4, 3.6)
      ..quadraticBezierTo(19.2, 2.6, 18.3, 3.2)
      ..lineTo(13.0, 6.6)
      ..close();
    canvas.sticker(earL, art.coat, l);
    canvas.sticker(earR, art.coat, l);
    final inner = Paint()..color = const Color(0xFFF2A08B);
    canvas.drawPath(
      Path()..moveTo(5.6, 9.2)..lineTo(5.9, 5.2)..lineTo(9.2, 7.3)..close(),
      inner,
    );
    canvas.drawPath(
      Path()..moveTo(18.4, 9.2)..lineTo(18.1, 5.2)..lineTo(14.8, 7.3)..close(),
      inner,
    );

    canvas.stickerOval(
      Rect.fromCenter(center: const Offset(12, 13.6), width: 17.8, height: 15.0),
      art.coat,
      l,
    );

    // Forehead stripes — the ginger's tabby mark.
    final stripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = art.shade;
    canvas.drawLine(const Offset(9.4, 7.2), const Offset(10.0, 9.8), stripe);
    canvas.drawLine(const Offset(12.0, 6.6), const Offset(12.0, 9.6), stripe);
    canvas.drawLine(const Offset(14.6, 7.2), const Offset(14.0, 9.8), stripe);

    // Muzzle.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 16.6), width: 9.8, height: 5.6),
      Paint()..color = ZbTokens.creamLogo,
    );

    blush(canvas, y: 15.2, spread: 6.2);
    happyEyes(canvas, y: 13.0, spread: 3.6);

    final nose = Path()
      ..moveTo(10.8, 15.1)
      ..lineTo(13.2, 15.1)
      ..quadraticBezierTo(12.0, 17.2, 10.8, 15.1)
      ..close();
    canvas.drawPath(nose, Paint()..color = art.accent);
    catMouth(canvas, const Offset(12, 16.4), reach: 1.9, drop: 1.6);

    if (!detailed) return;
    final whisker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.55);
    canvas.drawLine(const Offset(2.6, 14.4), const Offset(6.4, 15.0), whisker);
    canvas.drawLine(const Offset(2.8, 16.8), const Offset(6.4, 16.3), whisker);
    canvas.drawLine(const Offset(21.4, 14.4), const Offset(17.6, 15.0), whisker);
    canvas.drawLine(const Offset(21.2, 16.8), const Offset(17.6, 16.3), whisker);
    glossAt(canvas, const Offset(7.4, 9.0), w: 3.0, h: 1.4, alpha: 0.5);
  }
}

/// The mascot's dog: cream face, brown floppy ears, a patch over one eye, a
/// big nose and the tongue-out grin.
class _DogPainter extends _SpeciesPainter {
  const _DogPainter({required super.art, required super.size});

  void _ear(Canvas canvas, double cx, double tilt) {
    canvas.save();
    canvas.translate(cx, 12.2);
    canvas.rotate(tilt);
    canvas.stickerOval(
      Rect.fromCenter(center: Offset.zero, width: 5.8, height: 12.4),
      art.shade,
      line,
    );
    canvas.restore();
  }

  @override
  void draw(Canvas canvas) {
    final l = line;
    _ear(canvas, 4.6, -0.16);
    _ear(canvas, 19.4, 0.16);

    canvas.stickerOval(
      Rect.fromCenter(center: const Offset(12, 12.8), width: 16.8, height: 15.6),
      art.coat,
      l,
    );
    // The patch.
    canvas.drawCircle(const Offset(15.7, 11.0), 3.7, Paint()..color = art.shade.withValues(alpha: 0.92));

    happyEyes(canvas, y: 12.2, spread: 3.6);
    blush(canvas, y: 14.4, spread: 6.2);

    // Nose.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 15.4), width: 4.0, height: 2.9),
      Paint()..color = ZbTokens.inkWarm,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(11.2, 14.8), width: 1.2, height: 0.7),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Open grin with the tongue.
    final mouth = Path()
      ..moveTo(9.0, 17.0)
      ..quadraticBezierTo(12.0, 17.6, 15.0, 17.0)
      ..quadraticBezierTo(14.6, 20.8, 12.0, 20.8)
      ..quadraticBezierTo(9.4, 20.8, 9.0, 17.0)
      ..close();
    canvas.drawPath(mouth, Paint()..color = ZbTokens.inkWarm);
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 20.0), width: 3.4, height: 3.4),
      Paint()..color = const Color(0xFFF07A6A),
    );
    canvas.restore();
    canvas.drawPath(mouth, thin(1.0));

    glossAt(canvas, const Offset(7.6, 8.4), w: 3.0, h: 1.4, alpha: 0.6);
  }
}

/// A plump little bird facing into the reading direction: amber body, a
/// paler belly, a coral crest and a hooked orange beak.
class _BirdPainter extends _SpeciesPainter {
  const _BirdPainter({required super.art, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;

    // Tail feathers, tucked behind.
    final tail = Path()
      ..moveTo(17.4, 16.4)
      ..quadraticBezierTo(22.6, 16.0, 22.4, 20.6)
      ..quadraticBezierTo(19.0, 20.0, 17.4, 16.4)
      ..close();
    canvas.sticker(tail, art.shade, l);

    // Crest: two soft feathers leaning back from the crown.
    for (final (c, r) in const [(Offset(10.6, 4.0), 0.75), (Offset(13.2, 3.4), 0.35)]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(r);
      canvas.stickerOval(
        Rect.fromCenter(center: Offset.zero, width: 2.6, height: 5.2),
        art.accent,
        thin(1.1),
      );
      canvas.restore();
    }

    canvas.stickerOval(
      Rect.fromCenter(center: const Offset(12, 13.4), width: 15.6, height: 15.2),
      art.coat,
      l,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(11.4, 16.6), width: 8.6, height: 6.4),
      Paint()..color = const Color(0xFFFBE08E),
    );

    // Wing.
    final wing = Path()
      ..moveTo(15.2, 10.6)
      ..quadraticBezierTo(21.4, 12.2, 16.8, 18.6)
      ..quadraticBezierTo(14.2, 15.2, 15.2, 10.6)
      ..close();
    canvas.sticker(wing, art.shade, l);

    // Beak.
    final beak = Path()
      ..moveTo(6.6, 11.8)
      ..quadraticBezierTo(1.6, 13.2, 6.0, 15.8)
      ..quadraticBezierTo(7.4, 14.0, 6.6, 11.8)
      ..close();
    canvas.sticker(beak, ZbTokens.orange, thin(1.1));

    roundEye(canvas, const Offset(9.6, 11.2), r: 2.2);
    blush(canvas, y: 14.6, spread: 3.4, w: 2.6);
    glossAt(canvas, const Offset(9.4, 7.4), w: 3.0, h: 1.3, alpha: 0.5);
  }
}

/// A round teal fish swimming toward the start edge, fins and a fan tail one
/// shade deeper, bubbles rising ahead of it.
class _FishPainter extends _SpeciesPainter {
  const _FishPainter({required super.art, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;

    final tail = Path()
      ..moveTo(18.0, 13.2)
      ..lineTo(22.8, 8.0)
      ..quadraticBezierTo(23.6, 13.2, 22.8, 18.4)
      ..close();
    canvas.sticker(tail, art.shade, l);
    final topFin = Path()
      ..moveTo(9.6, 7.4)
      ..quadraticBezierTo(12.6, 2.6, 16.0, 7.8)
      ..close();
    canvas.sticker(topFin, art.shade, l);
    final lowFin = Path()
      ..moveTo(10.8, 19.0)
      ..quadraticBezierTo(13.2, 22.4, 15.6, 18.8)
      ..close();
    canvas.sticker(lowFin, art.shade, l);

    canvas.stickerOval(
      Rect.fromCenter(center: const Offset(11.6, 13.2), width: 16.4, height: 12.8),
      art.coat,
      l,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(11.0, 15.6), width: 9.6, height: 4.8),
      Paint()..color = const Color(0xFFA9DBD5),
    );

    // Scales.
    final scale = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.35);
    for (final c in const [Offset(13.4, 10.6), Offset(16.0, 12.8), Offset(13.6, 14.6)]) {
      canvas.drawArc(Rect.fromCenter(center: c, width: 3.0, height: 3.0), 0.6, 1.9, false, scale);
    }
    // Side fin.
    final side = Path()
      ..moveTo(9.8, 13.6)
      ..quadraticBezierTo(7.2, 16.8, 11.4, 16.2)
      ..close();
    canvas.sticker(side, art.shade, thin(1.0));

    roundEye(canvas, const Offset(6.8, 11.8), r: 2.1);
    canvas.drawPath(
      Path()
        ..moveTo(4.2, 14.6)
        ..quadraticBezierTo(5.2, 15.8, 6.4, 14.9),
      thin(1.1),
    );
    if (!detailed) return;
    final bubble = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = art.shade.withValues(alpha: 0.7);
    canvas.drawCircle(const Offset(3.0, 6.4), 1.2, bubble);
    canvas.drawCircle(const Offset(5.0, 3.8), 0.8, bubble);
    glossAt(canvas, const Offset(8.6, 9.2), w: 2.6, h: 1.2, alpha: 0.5);
  }
}

/// The small-pets bucket drawn as a rabbit: two tall ears with pink insides,
/// full cheeks, and the two front teeth.
class _SmallPainter extends _SpeciesPainter {
  const _SmallPainter({required super.art, required super.size});

  void _ear(Canvas canvas, double cx, double tilt) {
    canvas.save();
    canvas.translate(cx, 6.0);
    canvas.rotate(tilt);
    canvas.stickerOval(Rect.fromCenter(center: Offset.zero, width: 4.8, height: 10.8), art.coat, line);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.4), width: 2.2, height: 7.2),
      Paint()..color = const Color(0xFFF2A6A0).withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  void draw(Canvas canvas) {
    _ear(canvas, 8.6, -0.14);
    _ear(canvas, 15.4, 0.14);

    canvas.stickerOval(
      Rect.fromCenter(center: const Offset(12, 14.6), width: 16.6, height: 13.8),
      art.coat,
      line,
    );

    happyEyes(canvas, y: 13.6, spread: 3.6);
    blush(canvas, y: 16.0, spread: 6.0);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 16.3), width: 2.5, height: 1.8),
      Paint()..color = art.accent,
    );
    catMouth(canvas, const Offset(12, 17.0), reach: 1.5, drop: 1.3);

    // Teeth.
    canvas.stickerRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(12, 19.1), width: 2.8, height: 2.3),
        const Radius.circular(0.6),
      ),
      ZbTokens.creamLogo,
      thin(0.8),
    );
    canvas.drawLine(const Offset(12, 18.1), const Offset(12, 20.1), thin(0.7));

    if (!detailed) return;
    final whisker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = ZbTokens.inkWarm.withValues(alpha: 0.5);
    canvas.drawLine(const Offset(3.6, 15.6), const Offset(6.6, 16.0), whisker);
    canvas.drawLine(const Offset(20.4, 15.6), const Offset(17.4, 16.0), whisker);
    glossAt(canvas, const Offset(7.6, 10.4), w: 2.8, h: 1.3, alpha: 0.5);
  }
}

/// A turtle facing the start edge: a domed green shell with darker plates,
/// a round head with one big eye, and two stubby feet.
class _ReptilePainter extends _SpeciesPainter {
  const _ReptilePainter({required super.art, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final l = line;
    const skin = Color(0xFFA9D48B);

    // Feet, tucked under the shell.
    for (final c in const [Offset(9.4, 18.6), Offset(17.0, 18.6)]) {
      canvas.stickerOval(Rect.fromCenter(center: c, width: 4.2, height: 3.0), skin, thin(1.1));
    }
    // Head.
    canvas.stickerCircle(const Offset(5.4, 12.4), 3.9, skin, l);

    // Shell: a dome over a flat rim.
    final shell = Path()
      ..moveTo(7.2, 16.6)
      ..quadraticBezierTo(7.4, 6.4, 14.4, 6.2)
      ..quadraticBezierTo(21.6, 6.2, 21.8, 16.6)
      ..close();
    canvas.sticker(shell, art.coat, l);
    canvas.stickerRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(6.4, 15.8, 22.6, 18.6), const Radius.circular(1.4)),
      art.shade,
      l,
    );
    // Plates.
    final plate = Paint()..color = art.shade.withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: const Offset(14.4, 11.4), width: 4.6, height: 3.8), plate);
    canvas.drawOval(Rect.fromCenter(center: const Offset(10.4, 13.6), width: 2.8, height: 2.4), plate);
    canvas.drawOval(Rect.fromCenter(center: const Offset(18.4, 13.6), width: 2.8, height: 2.4), plate);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12.6, 8.6), width: 2.2, height: 1.8), plate);
    canvas.drawOval(Rect.fromCenter(center: const Offset(16.8, 8.9), width: 2.2, height: 1.8), plate);

    roundEye(canvas, const Offset(4.4, 11.6), r: 1.7);
    canvas.drawPath(
      Path()
        ..moveTo(2.6, 13.8)
        ..quadraticBezierTo(3.8, 15.0, 5.6, 14.4),
      thin(1.0),
    );
    if (!detailed) return;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(6.4, 14.4), width: 2.0, height: 1.2),
      Paint()..color = ZbTokens.logoCoral.withValues(alpha: 0.3),
    );
    glossAt(canvas, const Offset(11.0, 8.8), w: 3.0, h: 1.2, angle: -0.5, alpha: 0.4);
  }
}

/// Anything else: the logo's heart with a paw inside. Honest — and warmer than
/// a wrong animal.
class _OtherPainter extends _SpeciesPainter {
  const _OtherPainter({required super.art, required super.size});

  @override
  void draw(Canvas canvas) {
    canvas.sticker(heartPath(const Rect.fromLTRB(2.6, 4.0, 21.4, 21.0)), art.coat, line);
    final paw = Paint()..color = art.accent.withValues(alpha: 0.95);
    canvas.drawOval(Rect.fromCenter(center: const Offset(12, 13.6), width: 4.6, height: 3.6), paw);
    for (final t in const [Offset(9.4, 10.9), Offset(10.9, 9.6), Offset(13.1, 9.6), Offset(14.6, 10.9)]) {
      canvas.drawOval(Rect.fromCenter(center: t, width: 1.8, height: 2.2), paw);
    }
    if (!detailed) return;
    sparkleAt(canvas, const Offset(20.2, 4.2), 3.4);
    glossAt(canvas, const Offset(7.0, 8.2), w: 3.0, h: 1.4, alpha: 0.5);
  }
}
