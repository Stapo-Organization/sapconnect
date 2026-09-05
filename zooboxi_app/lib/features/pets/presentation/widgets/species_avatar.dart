import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../data/pet_models.dart';

/// The coat a species is drawn in.
///
/// These are the logo's own warm colours rather than the UI palette: an avatar
/// is a character, not a control, so a cat is cardboard-tan and a dog is the
/// logo's coral — the same hand that drew the mascot on the box.
@immutable
class SpeciesArt {
  const SpeciesArt({required this.coat, required this.shade, required this.accent});

  /// The main fill.
  final Color coat;

  /// Ears, muzzle, fins — one step deeper than [coat].
  final Color shade;

  /// The one saturated detail: a beak, a collar, a fin edge.
  final Color accent;

  static SpeciesArt of(PetSpecies species) => switch (species) {
        PetSpecies.cat => const SpeciesArt(
            coat: ZbTokens.cardboard,
            shade: Color(0xFFC97F45),
            accent: ZbTokens.logoCoral,
          ),
        PetSpecies.dog => const SpeciesArt(
            coat: ZbTokens.logoCoral,
            shade: Color(0xFFC85F33),
            accent: ZbTokens.creamLogo,
          ),
        PetSpecies.bird => const SpeciesArt(
            coat: ZbTokens.amber,
            shade: Color(0xFFDDA518),
            accent: ZbTokens.logoCoral,
          ),
        PetSpecies.fish => const SpeciesArt(
            coat: ZbTokens.logoTeal,
            shade: ZbTokens.tealDark,
            accent: ZbTokens.amber,
          ),
        PetSpecies.small => const SpeciesArt(
            coat: ZbTokens.peach,
            shade: Color(0xFFE9BE95),
            accent: ZbTokens.logoCoral,
          ),
        PetSpecies.reptile => const SpeciesArt(
            coat: Color(0xFF7FBF6A),
            shade: Color(0xFF5E9C4C),
            accent: ZbTokens.amber,
          ),
        PetSpecies.other => const SpeciesArt(
            coat: ZbTokens.logoTeal,
            shade: ZbTokens.tealDark,
            accent: ZbTokens.sparkAmber,
          ),
      };
}

/// A drawn portrait for one species, in the app's painted icon language.
///
/// No emoji: an emoji is the OS's drawing, and it lands in the middle of a
/// screen that is otherwise entirely ours. These are the same 24-unit grid,
/// the same warm outline weight and the same bubbly proportions as the tab bar
/// glyphs, so a pet card belongs to the same world as the cart icon.
class SpeciesAvatar extends StatelessWidget {
  const SpeciesAvatar({
    super.key,
    required this.species,
    this.size = 56,
    this.selected = false,
    this.showWell = true,
  });

  final PetSpecies species;
  final double size;

  /// Rings the well in the species' own colour — the picker's selected state.
  final bool selected;

  /// False drops the tinted disc and draws the portrait alone, for a card
  /// that already has a surface of its own.
  final bool showWell;

  @override
  Widget build(BuildContext context) {
    final art = SpeciesArt.of(species);
    final ink = resolveZbInk(context);
    final glyph = SizedBox.square(
      dimension: size * 0.74,
      child: CustomPaint(
        size: Size.square(size * 0.74),
        painter: _painter(art, ink, size * 0.74),
      ),
    );

    if (!showWell) return SizedBox.square(dimension: size, child: Center(child: glyph));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: art.coat.withValues(alpha: context.isDark ? 0.22 : 0.16),
        border: Border.all(
          color: selected
              ? art.shade
              : art.coat.withValues(alpha: context.isDark ? 0.42 : 0.34),
          width: selected ? 2 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: glyph,
    );
  }

  ZbIconPainter _painter(SpeciesArt art, Color ink, double side) => switch (species) {
        PetSpecies.cat => _CatPainter(art: art, ink: ink, size: side),
        PetSpecies.dog => _DogPainter(art: art, ink: ink, size: side),
        PetSpecies.bird => _BirdPainter(art: art, ink: ink, size: side),
        PetSpecies.fish => _FishPainter(art: art, ink: ink, size: side),
        PetSpecies.small => _SmallPainter(art: art, ink: ink, size: side),
        PetSpecies.reptile => _ReptilePainter(art: art, ink: ink, size: side),
        PetSpecies.other => _OtherPainter(art: art, ink: ink, size: side),
      };
}

/// Shared plumbing for the seven portraits: they are always fully filled
/// stickers (an outline-only pet would read as a placeholder), and they all
/// draw the same eyes so the family looks related.
abstract class _SpeciesPainter extends ZbIconPainter {
  const _SpeciesPainter({
    required this.art,
    required super.ink,
    required super.size,
  }) : super(fill: 1);

  final SpeciesArt art;

  /// Two round eyes plus their gloss — the whole set's expression.
  void eyes(Canvas canvas, {required double y, double spread = 2.6, double r = 0.95}) {
    final paint = Paint()..color = featureInk;
    canvas.drawCircle(Offset(12 - spread, y), r, paint);
    canvas.drawCircle(Offset(12 + spread, y), r, paint);
    if (!detailed) return;
    final spark = Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(12 - spread + r * 0.34, y - r * 0.36), r * 0.32, spark);
    canvas.drawCircle(Offset(12 + spread + r * 0.34, y - r * 0.36), r * 0.32, spark);
  }

  /// The blush the logo's animals wear. Detail-floor gated like every other
  /// tertiary feature in the set.
  void blush(Canvas canvas, {required double y, double spread = 5.4}) {
    if (!detailed) return;
    final paint = Paint()..color = ZbTokens.logoCoral.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(12 - spread, y), width: 2.8, height: 1.8),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(12 + spread, y), width: 2.8, height: 1.8),
      paint,
    );
  }

  /// A filled-then-outlined shape, which is how every glyph in the set is
  /// built: colour first, one warm stroke on top.
  void solid(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, strokePaint());
  }

  void solidOval(Canvas canvas, Rect rect, Color color) {
    canvas.drawOval(rect, Paint()..color = color);
    canvas.drawOval(rect, strokePaint());
  }

  @override
  bool shouldRepaint(covariant _SpeciesPainter old) =>
      super.shouldRepaint(old) || old.art.coat != art.coat;
}

/// Round head, two pricked triangular ears, a button nose and whiskers.
class _CatPainter extends _SpeciesPainter {
  const _CatPainter({required super.art, required super.ink, required super.size});

  @override
  void draw(Canvas canvas) {
    final ear = Path()
      ..moveTo(6.4, 10.2)
      ..lineTo(7.4, 4.4)
      ..quadraticBezierTo(7.7, 3.6, 8.4, 4.2)
      ..lineTo(12.2, 7.4)
      ..close();
    final ear2 = Path()
      ..moveTo(17.6, 10.2)
      ..lineTo(16.6, 4.4)
      ..quadraticBezierTo(16.3, 3.6, 15.6, 4.2)
      ..lineTo(11.8, 7.4)
      ..close();
    solid(canvas, ear, art.shade);
    solid(canvas, ear2, art.shade);

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 13.4), width: 15.2, height: 13.4),
      art.coat,
    );

    blush(canvas, y: 15.4);
    eyes(canvas, y: 12.6, spread: 3.0);

    // Nose and mouth: one small triangle over a soft double curve.
    final nose = Path()
      ..moveTo(10.9, 15.2)
      ..lineTo(13.1, 15.2)
      ..lineTo(12, 16.5)
      ..close();
    canvas.drawPath(nose, Paint()..color = art.accent);
    final mouth = strokePaint(width: 1.1, color: featureInk);
    canvas.drawPath(
      Path()
        ..moveTo(12, 16.5)
        ..quadraticBezierTo(10.6, 18.0, 9.5, 16.8),
      mouth,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 16.5)
        ..quadraticBezierTo(13.4, 18.0, 14.5, 16.8),
      mouth,
    );

    if (!detailed) return;
    final whisker = strokePaint(width: 0.9, color: featureInk.withValues(alpha: 0.7));
    canvas.drawLine(const Offset(3.6, 14.6), const Offset(7.4, 15.2), whisker);
    canvas.drawLine(const Offset(3.8, 17.0), const Offset(7.4, 16.6), whisker);
    canvas.drawLine(const Offset(20.4, 14.6), const Offset(16.6, 15.2), whisker);
    canvas.drawLine(const Offset(20.2, 17.0), const Offset(16.6, 16.6), whisker);
  }
}

/// Round head, two floppy ears hanging past the jaw, a broad muzzle.
class _DogPainter extends _SpeciesPainter {
  const _DogPainter({required super.art, required super.ink, required super.size});

  @override
  void draw(Canvas canvas) {
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(5.4, 12.6), width: 5.2, height: 10.4),
      art.shade,
    );
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(18.6, 12.6), width: 5.2, height: 10.4),
      art.shade,
    );

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 12.6), width: 14.4, height: 13.2),
      art.coat,
    );

    // The muzzle is the dog's whole read: a pale panel low on the face.
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 16.2), width: 9.4, height: 6.4),
      art.accent,
    );

    eyes(canvas, y: 11.8, spread: 3.1);
    blush(canvas, y: 13.6, spread: 5.2);

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 14.6), width: 3.4, height: 2.5),
      featureInk,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 16.0)
        ..lineTo(12, 17.0)
        ..moveTo(12, 17.0)
        ..quadraticBezierTo(10.7, 18.6, 9.7, 17.2)
        ..moveTo(12, 17.0)
        ..quadraticBezierTo(13.3, 18.6, 14.3, 17.2),
      strokePaint(width: 1.1, color: featureInk),
    );
  }
}

/// A perched bird: round body, a crest feather, a wedge beak on the start
/// edge — so it faces into the reading direction in both languages.
class _BirdPainter extends _SpeciesPainter {
  const _BirdPainter({required super.art, required super.ink, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final crest = Path()
      ..moveTo(12.6, 5.6)
      ..quadraticBezierTo(11.4, 2.2, 14.6, 2.6)
      ..quadraticBezierTo(15.2, 4.4, 13.8, 5.9)
      ..close();
    solid(canvas, crest, art.accent);

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12.4, 13.0), width: 13.6, height: 14.4),
      art.coat,
    );

    // Wing: a leaf tucked against the body, one shade down.
    final wing = Path()
      ..moveTo(15.6, 10.6)
      ..quadraticBezierTo(19.4, 12.4, 15.8, 17.4)
      ..quadraticBezierTo(13.8, 14.2, 15.6, 10.6)
      ..close();
    solid(canvas, wing, art.shade);

    final beak = Path()
      ..moveTo(6.0, 12.0)
      ..lineTo(2.2, 13.6)
      ..lineTo(6.0, 15.4)
      ..close();
    solid(canvas, beak, art.accent);

    canvas.drawCircle(const Offset(9.0, 11.6), 1.05, Paint()..color = featureInk);
    if (detailed) {
      canvas.drawCircle(
        const Offset(9.36, 11.24),
        0.34,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9),
      );
    }
    blush(canvas, y: 14.2, spread: 4.2);
  }
}

/// A round fish with a fan tail on the end edge and one top fin.
class _FishPainter extends _SpeciesPainter {
  const _FishPainter({required super.art, required super.ink, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final tail = Path()
      ..moveTo(17.6, 13.2)
      ..lineTo(22.4, 8.6)
      ..quadraticBezierTo(23.2, 13.2, 22.4, 17.8)
      ..close();
    solid(canvas, tail, art.shade);

    final fin = Path()
      ..moveTo(10.4, 6.6)
      ..quadraticBezierTo(13.6, 4.0, 14.4, 8.2)
      ..close();
    solid(canvas, fin, art.shade);

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(11.4, 13.4), width: 15.2, height: 12.4),
      art.coat,
    );

    // Gill line — the one stroke that says "fish" rather than "oval".
    canvas.drawPath(
      Path()
        ..moveTo(8.6, 9.4)
        ..quadraticBezierTo(6.8, 13.4, 8.6, 17.4),
      strokePaint(width: 1.2, color: featureInk.withValues(alpha: 0.55)),
    );

    canvas.drawCircle(const Offset(6.6, 12.4), 1.05, Paint()..color = featureInk);
    if (detailed) {
      canvas.drawCircle(
        const Offset(6.96, 12.04),
        0.34,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        const Offset(3.4, 6.6),
        1.0,
        Paint()..color = art.accent.withValues(alpha: 0.55),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(5.4, 15.6)
        ..quadraticBezierTo(6.8, 17.0, 8.2, 15.8),
      strokePaint(width: 1.1, color: featureInk),
    );
  }
}

/// The small-pets bucket — hamster, rabbit, guinea pig — drawn as a round
/// face with two tall ears and full cheeks.
class _SmallPainter extends _SpeciesPainter {
  const _SmallPainter({required super.art, required super.ink, required super.size});

  @override
  void draw(Canvas canvas) {
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(8.6, 6.4), width: 4.4, height: 8.2),
      art.shade,
    );
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(15.4, 6.4), width: 4.4, height: 8.2),
      art.shade,
    );

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 14.2), width: 15.0, height: 12.6),
      art.coat,
    );

    eyes(canvas, y: 13.2, spread: 3.2);
    blush(canvas, y: 16.0, spread: 5.4);

    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 16.0), width: 2.6, height: 2.0),
      art.accent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 17.0)
        ..quadraticBezierTo(10.9, 18.4, 10.0, 17.3)
        ..moveTo(12, 17.0)
        ..quadraticBezierTo(13.1, 18.4, 14.0, 17.3),
      strokePaint(width: 1.0, color: featureInk),
    );
    if (!detailed) return;
    // Two front teeth — the detail that turns a round face into a rodent.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(12, 18.8), width: 2.4, height: 1.8),
        const Radius.circular(0.5),
      ),
      Paint()..color = ZbTokens.creamLogo,
    );
    canvas.drawLine(
      const Offset(12, 18.0),
      const Offset(12, 19.6),
      strokePaint(width: 0.7, color: featureInk.withValues(alpha: 0.55)),
    );
  }
}

/// A friendly lizard head: a long snout on the start edge, one eye ridge and
/// a row of soft back scales.
class _ReptilePainter extends _SpeciesPainter {
  const _ReptilePainter({required super.art, required super.ink, required super.size});

  @override
  bool get mirrored => true;

  @override
  void draw(Canvas canvas) {
    final scales = Path()
      ..moveTo(13.0, 7.6)
      ..lineTo(14.6, 4.6)
      ..lineTo(16.2, 7.6)
      ..lineTo(17.8, 4.8)
      ..lineTo(19.4, 8.4)
      ..close();
    solid(canvas, scales, art.shade);

    final head = Path()
      ..moveTo(3.2, 14.4)
      ..quadraticBezierTo(3.0, 11.6, 6.4, 10.6)
      ..quadraticBezierTo(10.4, 9.0, 15.0, 8.6)
      ..quadraticBezierTo(21.0, 8.2, 21.2, 13.6)
      ..quadraticBezierTo(21.4, 18.4, 15.0, 18.6)
      ..quadraticBezierTo(9.2, 18.8, 6.0, 17.4)
      ..quadraticBezierTo(3.4, 16.4, 3.2, 14.4)
      ..close();
    solid(canvas, head, art.coat);

    canvas.drawCircle(const Offset(8.6, 13.0), 1.15, Paint()..color = featureInk);
    if (detailed) {
      canvas.drawCircle(
        const Offset(9.0, 12.6),
        0.36,
        Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        const Offset(17.2, 13.4),
        0.9,
        Paint()..color = art.shade.withValues(alpha: 0.7),
      );
    }
    // The tongue flick — a lizard with no tongue is a stone.
    canvas.drawPath(
      Path()
        ..moveTo(4.6, 15.6)
        ..lineTo(1.8, 16.6)
        ..moveTo(1.8, 16.6)
        ..lineTo(3.0, 17.2),
      strokePaint(width: 1.0, color: art.accent),
    );
  }
}

/// Anything else: the paw print. Honest rather than a wrong animal.
class _OtherPainter extends _SpeciesPainter {
  const _OtherPainter({required super.art, required super.ink, required super.size});

  static const List<Offset> _toes = [
    Offset(6.5, 11.2),
    Offset(9.9, 7.9),
    Offset(14.1, 7.9),
    Offset(17.5, 11.2),
  ];

  @override
  void draw(Canvas canvas) {
    solidOval(
      canvas,
      Rect.fromCenter(center: const Offset(12, 16.2), width: 9.6, height: 7.8),
      art.coat,
    );
    for (final toe in _toes) {
      solidOval(
        canvas,
        Rect.fromCenter(center: toe, width: 3.6, height: 4.4),
        art.coat,
      );
    }
    if (!detailed) return;
    canvas.drawCircle(
      const Offset(9.4, 14.6),
      0.85,
      Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.85),
    );
  }
}
