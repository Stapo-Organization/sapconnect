import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';

/// A real scratch card: teal foil over the prize, cleared with a finger.
///
/// Not a tap-to-flip dressed up as a scratch. The foil is painted into its own
/// layer and the finger punches holes in it with [BlendMode.clear], so what
/// comes off is exactly what was rubbed — and the reveal fires once, at
/// [threshold] of the surface cleared, rather than on some timer that would
/// make the gesture decorative.
///
/// Coverage is measured on a coarse grid rather than by counting pixels: it is
/// cheap enough to run on every pointer move, and 55% of a 24×12 grid is the
/// same "most of it is gone" a person sees.
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

class _ScratchCanvasState extends State<ScratchCanvas>
    with SingleTickerProviderStateMixin {
  /// Grid resolution for the coverage estimate.
  static const int _cols = 24;
  static const int _rows = 12;

  /// Stroke points in local coordinates; `null` breaks the path between two
  /// separate rubs so they aren't joined by a line the finger never drew.
  final List<Offset?> _points = [];
  final Set<int> _cleared = {};

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 0,
  );

  Size _size = Size.zero;
  bool _fired = false;

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
    _fade.dispose();
    super.dispose();
  }

  double get _brush {
    final side = math.min(_size.width, _size.height);
    return math.max(18, side * 0.16);
  }

  void _melt() {
    if (context.reduceMotion) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  void _startStroke(Offset point) {
    if (_fired) return;
    _points.add(null);
    _extend(point);
  }

  /// Marks every grid cell within a brush of the segment [_points.last] → [to].
  ///
  /// Interpolating the segment rather than only stamping the endpoint is what
  /// makes a fast swipe clear a continuous band instead of two dots — the
  /// pointer stream is sparse exactly when the finger is moving quickly.
  void _extend(Offset to) {
    if (_fired || _size.isEmpty) return;

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
    }

    if (from == null) {
      stamp(to);
    } else {
      final distance = (to - from).distance;
      final steps = math.max(1, (distance / (brush * 0.5)).ceil());
      for (var i = 1; i <= steps; i++) {
        stamp(Offset.lerp(from, to, i / steps)!);
      }
    }

    _points.add(to);
    setState(() {});

    if (_cleared.length / (_cols * _rows) >= widget.threshold) _reveal();
  }

  void _reveal() {
    if (_fired) return;
    _fired = true;
    Haptics.success();
    _melt();
    widget.onRevealed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);

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
                        scale: 1 + 0.04 * gone,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // `onPanDown`, not `onPanStart`: the foil has to
                          // start coming off where the finger landed, not
                          // where the drag was finally recognised — a slop's
                          // worth of untouched foil under the fingertip is
                          // exactly the thing that makes a scratch feel fake.
                          // It also covers a plain tap, which stamps one dab.
                          onPanDown: (details) => _startStroke(details.localPosition),
                          onPanUpdate: (details) => _extend(details.localPosition),
                          child: CustomPaint(
                            painter: _FoilPainter(
                              points: _points,
                              brush: _brush,
                              radius: widget.borderRadius,
                              label: widget.label,
                              hint: widget.hint,
                              textDirection: Directionality.of(context),
                              outline: cs.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The foil itself: a teal chip printed with paws, punched where the finger
/// has been. Everything happens inside one `saveLayer`, which is what keeps
/// [BlendMode.clear] from taking the prize behind it with it.
class _FoilPainter extends CustomPainter {
  const _FoilPainter({
    required this.points,
    required this.brush,
    required this.radius,
    required this.textDirection,
    required this.outline,
    this.label,
    this.hint,
  });

  final List<Offset?> points;
  final double brush;
  final double radius;
  final String? label;
  final String? hint;
  final TextDirection textDirection;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(bounds, Radius.circular(radius));

    canvas.saveLayer(bounds, Paint());

    canvas.drawRRect(
      rrect,
      Paint()
        // The gradient runs start→end, so it is handed the reading direction
        // explicitly: a raw canvas has no Directionality to resolve it from.
        ..shader = const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [ZbTokens.teal, ZbTokens.tealDeep],
        ).createShader(bounds, textDirection: textDirection),
    );

    _paws(canvas, size);
    _copy(canvas, size);

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
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = brush * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();
  }

  /// The printed paw motif — the same pad-and-four-toes shape as the icon set,
  /// scattered at a low opacity so it reads as foil texture, not as content.
  void _paws(Canvas canvas, Size size) {
    final paint = Paint()..color = ZbTokens.creamLogo.withValues(alpha: 0.13);
    const spots = <Offset>[
      Offset(0.12, 0.22),
      Offset(0.34, 0.72),
      Offset(0.58, 0.18),
      Offset(0.80, 0.62),
      Offset(0.92, 0.24),
      Offset(0.06, 0.74),
      Offset(0.68, 0.88),
    ];
    for (final spot in spots) {
      final centre = Offset(spot.dx * size.width, spot.dy * size.height);
      final scale = size.shortestSide / 190;
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.scale(scale);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 4), width: 15, height: 12),
        paint,
      );
      for (final toe in const [
        Offset(-8.5, -3.5),
        Offset(-3, -8),
        Offset(3, -8),
        Offset(8.5, -3.5),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: toe, width: 5.6, height: 7),
          paint,
        );
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
          color: ZbTokens.creamLogo,
          fontSize: math.min(26, size.shortestSide * 0.17),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: ZbTokens.tealDeep.withValues(alpha: 0.45),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
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
                color: ZbTokens.creamLogo.withValues(alpha: 0.82),
                fontSize: math.min(14, size.shortestSide * 0.095),
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: textDirection,
            textAlign: TextAlign.center,
          )..layout(maxWidth: size.width - 32));

    final block = title.height + (sub == null ? 0 : sub.height + 8);
    final top = (size.height - block) / 2;
    title.paint(canvas, Offset((size.width - title.width) / 2, top));
    sub?.paint(
      canvas,
      Offset((size.width - sub.width) / 2, top + title.height + 8),
    );
  }

  @override
  bool shouldRepaint(_FoilPainter old) =>
      old.points.length != points.length ||
      old.label != label ||
      old.hint != hint ||
      old.brush != brush;
}
