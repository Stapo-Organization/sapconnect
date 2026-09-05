import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';

/// A real scratch card: silver foil over the prize, cleared with a finger.
///
/// What makes it feel like foil rather than a tap-to-flip in disguise:
///
/// * The foil is metal — a brushed gradient with grain and two sheen bands,
///   printed with the brand in teal — and the finger punches through it with
///   [BlendMode.clear], so what comes off is exactly what was rubbed.
/// * The edge of every stroke is ragged: each step of the finger also drops
///   a few off-centre dabs, the way real latex crumbles instead of cutting.
/// * Shavings fall. Every move spawns a few flakes of foil that tumble under
///   gravity for half a second and vanish.
/// * The Taptic engine ticks under the finger every few points of travel —
///   the one sense a screen can borrow from a coin on cardboard.
/// * The reveal fires once, at [threshold]; the foil only melts away once the
///   finger lifts, so the card never vanishes under a hand still scratching.
class ScratchCanvas extends StatefulWidget {
  const ScratchCanvas({
    super.key,
    required this.child,
    required this.onRevealed,
    this.label,
    this.hint,
    this.revealed = false,
    this.threshold = 0.55,
    this.borderRadius = ZbTokens.rXl,
  });

  /// The prize, drawn underneath and uncovered as the foil goes.
  final Widget child;

  /// Fired exactly once, the moment [threshold] is crossed.
  final VoidCallback onRevealed;

  /// Foil copy — the headline and the "rub me" line.
  final String? label;
  final String? hint;

  /// Starts (or becomes) open with no foil at all: an already-revealed card,
  /// or the accessible "open it for me" path.
  final bool revealed;

  /// Fraction of the surface that must be cleared. 0.55 is the point at which
  /// a person has already read the prize and the rest is just tidying.
  final double threshold;

  final double borderRadius;

  @override
  State<ScratchCanvas> createState() => _ScratchCanvasState();
}

class _ScratchCanvasState extends State<ScratchCanvas> with TickerProviderStateMixin {
  /// Grid resolution for the coverage estimate.
  static const int _cols = 24;
  static const int _rows = 12;

  /// Stroke points in local coordinates; `null` breaks the path between two
  /// separate rubs so they aren't joined by a line the finger never drew.
  final List<Offset?> _points = [];

  /// Off-centre dabs that ragged the stroke edge. Replayed every paint, so
  /// they are generated once and stored — never re-rolled.
  final List<_Dab> _dabs = [];
  final Set<int> _cleared = {};
  final _Flakes _flakes = _Flakes();
  final math.Random _rng = math.Random(7);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 0,
  );
  late final Ticker _ticker = createTicker(_tick);

  Size _size = Size.zero;
  _FoilGrain? _grain;
  bool _fired = false;
  bool _down = false;
  double _travelSinceTick = 0;
  Duration _lastHaptic = Duration.zero;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.revealed) _fade.value = 1;
  }

  @override
  void didUpdateWidget(ScratchCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A card opened from outside (the accessible button, or a card that was
    // already revealed on the server) just melts the foil — it must not fire
    // the callback a second time.
    if (widget.revealed && !oldWidget.revealed) {
      _fired = true;
      _melt();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fade.dispose();
    _flakes.dispose();
    super.dispose();
  }

  double get _brush {
    final side = math.min(_size.width, _size.height);
    return math.max(16, side * 0.14);
  }

  double get _coverage => _cleared.length / (_cols * _rows);

  void _melt() {
    if (context.reduceMotion) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  void _startStroke(Offset point) {
    if (_fired && _fade.isAnimating) return;
    _down = true;
    _points.add(null);
    _extend(point);
  }

  void _endStroke() {
    _down = false;
    // The threshold may have been crossed mid-stroke; the foil waits for the
    // hand to leave before it goes.
    if (_fired && _fade.value == 0 && !_fade.isAnimating) _melt();
  }

  /// Marks every grid cell within a brush of the segment [_points.last] → [to],
  /// drops the ragged dabs along it, spawns flakes, and ticks the haptic.
  ///
  /// Interpolating the segment rather than only stamping the endpoint is what
  /// makes a fast swipe clear a continuous band instead of two dots — the
  /// pointer stream is sparse exactly when the finger is moving quickly.
  void _extend(Offset to) {
    if (_size.isEmpty || _fade.value > 0) return;

    final from = _points.isEmpty ? null : _points.last;
    final brush = _brush;
    final cellW = _size.width / _cols;
    final cellH = _size.height / _rows;

    void stamp(Offset at) {
      final minCol = ((at.dx - brush) / cellW).floor().clamp(0, _cols - 1);
      final maxCol = ((at.dx + brush) / cellW).ceil().clamp(0, _cols - 1);
      final minRow = ((at.dy - brush) / cellH).floor().clamp(0, _rows - 1);
      final maxRow = ((at.dy + brush) / cellH).ceil().clamp(0, _rows - 1);
      for (var col = minCol; col <= maxCol; col++) {
        for (var row = minRow; row <= maxRow; row++) {
          final centre = Offset((col + 0.5) * cellW, (row + 0.5) * cellH);
          if ((centre - at).distance <= brush) _cleared.add(row * _cols + col);
        }
      }
      // The ragged edge: two or three crumbs just outside the brush.
      for (var i = 0; i < 3; i++) {
        final angle = _rng.nextDouble() * math.pi * 2;
        final dist = brush * (0.75 + _rng.nextDouble() * 0.45);
        _dabs.add(_Dab(
          at + Offset(math.cos(angle), math.sin(angle)) * dist,
          brush * (0.16 + _rng.nextDouble() * 0.22),
        ));
      }
    }

    if (from == null) {
      stamp(to);
      _flakes.spawn(to, Offset.zero, _rng, count: 4);
    } else {
      final delta = to - from;
      final distance = delta.distance;
      final steps = math.max(1, (distance / (brush * 0.45)).ceil());
      for (var i = 1; i <= steps; i++) {
        stamp(Offset.lerp(from, to, i / steps)!);
      }
      _flakes.spawn(to, delta, _rng, count: distance > 2 ? 3 : 1);
      _travelSinceTick += distance;
    }

    _points.add(to);
    _startTicking();
    setState(() {});

    _hapticTick();

    if (!_fired && _coverage >= widget.threshold) _reveal();
  }

  /// The scratch under the finger, as touch: a selection click every ~18pt of
  /// travel, never more often than every 45ms so a fast swipe reads as a
  /// buzz, not a drumroll.
  void _hapticTick() {
    if (_travelSinceTick < 18) return;
    final now = _ticker.isActive ? _lastTick : Duration.zero;
    if (now - _lastHaptic < const Duration(milliseconds: 45) && now != Duration.zero) return;
    _travelSinceTick = 0;
    _lastHaptic = now;
    HapticFeedback.selectionClick();
  }

  void _reveal() {
    if (_fired) return;
    _fired = true;
    Haptics.success();
    widget.onRevealed();
    if (!_down) _melt();
  }

  void _startTicking() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _flakes.step(dt.clamp(0.0, 0.05), _size);
    if (_flakes.isEmpty && !_down) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size) {
          _size = size;
          _grain = _FoilGrain.generate(size);
        }
        final textDirection = Directionality.of(context);

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: widget.child,
            ),
            if (!widget.revealed || _fade.value < 1)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _fade,
                  builder: (context, _) {
                    final gone = _fade.value;
                    if (gone >= 1) return const SizedBox.shrink();
                    return Opacity(
                      opacity: 1 - gone,
                      child: Transform.scale(
                        scale: 1 + 0.05 * gone,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // `onPanDown`, not `onPanStart`: the foil has to
                          // start coming off where the finger landed, not
                          // where the drag was finally recognised — a slop's
                          // worth of untouched foil under the fingertip is
                          // exactly the thing that makes a scratch feel fake.
                          onPanDown: (d) => _startStroke(d.localPosition),
                          onPanUpdate: (d) => _extend(d.localPosition),
                          onPanEnd: (_) => _endStroke(),
                          onPanCancel: _endStroke,
                          child: CustomPaint(
                            painter: _FoilPainter(
                              points: _points,
                              dabs: _dabs,
                              brush: _brush,
                              radius: widget.borderRadius,
                              label: widget.label,
                              hint: widget.hint,
                              textDirection: textDirection,
                              grain: _grain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // The shavings ride above everything, and never catch a touch.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _FlakesPainter(_flakes)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dab {
  const _Dab(this.centre, this.radius);

  final Offset centre;
  final double radius;
}

/// The falling foil shavings. A tiny particle system: position, velocity,
/// spin, a life in seconds, and one of three silver tones.
class _Flake {
  _Flake(this.p, this.v, this.spin, this.size, this.color) : life = 0.55 + size * 0.02;

  Offset p;
  Offset v;
  double rot = 0;
  final double spin;
  final double size;
  final Color color;
  double life;
}

class _Flakes extends ChangeNotifier {
  final List<_Flake> _items = [];

  static const int _max = 140;
  static const double _gravity = 900;

  bool get isEmpty => _items.isEmpty;
  List<_Flake> get items => _items;

  void spawn(Offset at, Offset motion, math.Random rng, {int count = 3}) {
    for (var i = 0; i < count && _items.length < _max; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 40 + rng.nextDouble() * 120;
      // Flakes fly a little against the finger's travel, like shavings
      // pushed off the front of a coin.
      final kick = motion.distance > 0 ? motion / motion.distance * -30 : Offset.zero;
      _items.add(_Flake(
        at + Offset(math.cos(angle), math.sin(angle)) * (2 + rng.nextDouble() * 8),
        Offset(math.cos(angle) * speed, math.sin(angle) * speed - 60) + kick,
        (rng.nextDouble() - 0.5) * 14,
        2.2 + rng.nextDouble() * 3.4,
        _tones[rng.nextInt(_tones.length)],
      ));
    }
  }

  static const List<Color> _tones = [
    Color(0xFFB8BEC3),
    Color(0xFFD5DADD),
    Color(0xFF9DA5AB),
    Color(0xFFEAEDEF),
  ];

  void step(double dt, Size bounds) {
    if (_items.isEmpty) return;
    for (final f in _items) {
      f.v = Offset(f.v.dx * 0.985, f.v.dy + _gravity * dt);
      f.p += f.v * dt;
      f.rot += f.spin * dt;
      f.life -= dt;
    }
    _items.removeWhere((f) => f.life <= 0 || f.p.dy > bounds.height + 20);
    notifyListeners();
  }
}

class _FlakesPainter extends CustomPainter {
  _FlakesPainter(this.flakes) : super(repaint: flakes);

  final _Flakes flakes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flakes.items) {
      final alpha = (f.life / 0.55).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(f.p.dx, f.p.dy);
      canvas.rotate(f.rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: f.size * 1.6, height: f.size),
          const Radius.circular(0.8),
        ),
        Paint()..color = f.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FlakesPainter old) => old.flakes != flakes;
}

/// The brushed grain of the foil, generated once per size so it never
/// shimmers between frames: a few hundred short horizontal hairlines at
/// random alpha, plus the sheen bands' positions.
class _FoilGrain {
  const _FoilGrain(this.lines);

  /// (y, x0, x1, alpha)
  final List<(double, double, double, double)> lines;

  static _FoilGrain generate(Size size) {
    final rng = math.Random(size.width.round() * 31 + size.height.round());
    final lines = <(double, double, double, double)>[];
    final count = (size.height / 2.2).round();
    for (var i = 0; i < count; i++) {
      final y = rng.nextDouble() * size.height;
      final x0 = rng.nextDouble() * size.width;
      final len = 12 + rng.nextDouble() * size.width * 0.35;
      lines.add((y, x0, math.min(size.width, x0 + len), 0.05 + rng.nextDouble() * 0.16));
    }
    return _FoilGrain(lines);
  }
}

/// The foil itself: brushed silver printed with the brand, punched where the
/// finger has been. Everything happens inside one `saveLayer`, which is what
/// keeps [BlendMode.clear] from taking the prize behind it with it.
class _FoilPainter extends CustomPainter {
  const _FoilPainter({
    required this.points,
    required this.dabs,
    required this.brush,
    required this.radius,
    required this.textDirection,
    required this.grain,
    this.label,
    this.hint,
  });

  final List<Offset?> points;
  final List<_Dab> dabs;
  final double brush;
  final double radius;
  final String? label;
  final String? hint;
  final TextDirection textDirection;
  final _FoilGrain? grain;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(radius));

    canvas.saveLayer(bounds, Paint());
    canvas.clipRRect(rrect);

    // Metal: a diagonal gradient that goes light–dark–light, like a sheet
    // catching the light along one axis.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE9ECEE),
            Color(0xFFC3C9CE),
            Color(0xFFAEB6BC),
            Color(0xFFD8DDE0),
            Color(0xFFB9C0C5),
          ],
          stops: [0.0, 0.3, 0.5, 0.72, 1.0],
        ).createShader(bounds),
    );

    // Grain.
    final g = grain;
    if (g != null) {
      final hair = Paint()..strokeWidth = 1;
      for (final (y, x0, x1, a) in g.lines) {
        hair.color = Colors.white.withValues(alpha: a);
        canvas.drawLine(Offset(x0, y), Offset(x1, y), hair);
      }
      final dark = Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFF6C767D).withValues(alpha: 0.10);
      for (var i = 0; i < g.lines.length; i += 3) {
        final (y, x0, x1, _) = g.lines[i];
        canvas.drawLine(Offset(x0, y + 1.5), Offset(x1, y + 1.5), dark);
      }
    }

    // Two sheen bands across the sheet.
    for (final (pos, w, a) in const [(0.22, 0.10, 0.34), (0.66, 0.06, 0.22)]) {
      final band = Path()
        ..moveTo(size.width * (pos - w) + size.height * 0.5, 0)
        ..lineTo(size.width * (pos + w) + size.height * 0.5, 0)
        ..lineTo(size.width * (pos + w) - size.height * 0.5, size.height)
        ..lineTo(size.width * (pos - w) - size.height * 0.5, size.height)
        ..close();
      canvas.drawPath(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: a),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(band.getBounds()),
      );
    }

    _print(canvas, size);
    _copy(canvas, size);

    // The scratch.
    if (points.isNotEmpty) {
      final path = Path();
      var open = false;
      for (final point in points) {
        if (point == null) {
          open = false;
          continue;
        }
        if (!open) {
          path.moveTo(point.dx, point.dy);
          open = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      final clear = Paint()..blendMode = BlendMode.clear;
      canvas.drawPath(
        path,
        clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = brush * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final crumb = Paint()..blendMode = BlendMode.clear;
      for (final dab in dabs) {
        canvas.drawCircle(dab.centre, dab.radius, crumb);
      }
    }

    canvas.restore();
  }

  /// The brand printed on the foil: paws and sparkles in teal at low ink, the
  /// way a real card is overprinted so a blank one still says whose it is.
  void _print(Canvas canvas, Size size) {
    final paint = Paint()..color = ZbTokens.tealDeep.withValues(alpha: 0.16);
    const spots = <(double, double, double)>[
      (0.10, 0.20, 0.55),
      (0.30, 0.78, -0.4),
      (0.56, 0.16, 0.2),
      (0.82, 0.66, 0.7),
      (0.93, 0.22, -0.3),
      (0.06, 0.76, 0.1),
      (0.68, 0.90, -0.6),
    ];
    final scale = size.shortestSide / 210;
    for (final (fx, fy, rot) in spots) {
      canvas.save();
      canvas.translate(fx * size.width, fy * size.height);
      canvas.rotate(rot);
      canvas.scale(scale);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 4), width: 15, height: 12), paint);
      for (final toe in const [Offset(-8.5, -3.5), Offset(-3, -8), Offset(3, -8), Offset(8.5, -3.5)]) {
        canvas.drawOval(Rect.fromCenter(center: toe, width: 5.6, height: 7), paint);
      }
      canvas.restore();
    }
  }

  void _copy(Canvas canvas, Size size) {
    final headline = label;
    if (headline == null || headline.isEmpty) return;

    final title = TextPainter(
      text: TextSpan(
        text: headline,
        style: TextStyle(
          color: ZbTokens.tealDeep,
          fontSize: math.min(26, size.shortestSide * 0.17),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 0, offset: const Offset(0, 1)),
          ],
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 32);

    final sub = hint == null || hint!.isEmpty
        ? null
        : (TextPainter(
            text: TextSpan(
              text: hint,
              style: TextStyle(
                color: const Color(0xFF3E4A50),
                fontSize: math.min(14, size.shortestSide * 0.095),
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: textDirection,
            textAlign: TextAlign.center,
          )..layout(maxWidth: size.width - 32));

    final block = title.height + (sub == null ? 0 : sub.height + 8);
    final top = (size.height - block) / 2;
    title.paint(canvas, Offset((size.width - title.width) / 2, top));
    sub?.paint(canvas, Offset((size.width - sub.width) / 2, top + title.height + 8));
  }

  @override
  bool shouldRepaint(_FoilPainter old) =>
      old.points.length != points.length ||
      old.dabs.length != dabs.length ||
      old.label != label ||
      old.hint != hint ||
      old.brush != brush ||
      old.grain != grain;
}
