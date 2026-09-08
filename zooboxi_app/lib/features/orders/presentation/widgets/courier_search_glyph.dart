import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../../../core/motion/motion.dart';
import '../../../../l10n/app_localizations.dart';

/// «نبحث عن مندوب» — the wait, drawn.
///
/// Searching is the only phase with nothing to report: no name, no position,
/// no minutes. It is also the phase a customer is most likely to sit and stare
/// at, because it is the one that decides whether the order happens at all. A
/// static icon in that slot reads as a stalled screen.
///
/// So it is drawn as a radar looking outward: a sweep arm turning through a
/// faint dial, and rings leaving the centre in a staggered rhythm. The motion
/// is outward and repeating, which is the shape of the actual thing happening
/// — a request going out to riders further and further away, again and again,
/// until one takes it.
///
/// Everything scales off [size], so the same glyph is correct at 40px in the
/// bar above the tab bar and at 38px on the order screen.
class CourierSearchGlyph extends StatefulWidget {
  const CourierSearchGlyph({
    super.key,
    required this.tone,
    this.size = 40,
    this.icon = Icons.two_wheeler_rounded,
  });

  final Color tone;
  final double size;
  final IconData icon;

  @override
  State<CourierSearchGlyph> createState() => _CourierSearchGlyphState();
}

class _CourierSearchGlyphState extends State<CourierSearchGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion is a MediaQuery, so this cannot be decided in initState.
    // With it on, the dial and the icon still draw — the customer keeps the
    // meaning, loses only the movement.
    if (context.reduceMotion) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = Center(
      child: Icon(widget.icon, size: widget.size * 0.4, color: widget.tone),
    );

    if (!_c.isAnimating) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RadarPainter(t: 0, tone: widget.tone, still: true),
          child: core,
        ),
      );
    }

    // The rings repaint every frame; whatever is behind this — two layers of
    // glass, in the bar's case — must not be dragged into that.
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            painter: _RadarPainter(t: _c.value, tone: widget.tone),
            child: child,
          ),
          child: core,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.t, required this.tone, this.still = false});

  /// 0 → 1, one full turn of the sweep.
  final double t;
  final Color tone;
  final bool still;

  /// Rings in flight at once. Three is enough to read as a rhythm; more turns
  /// the glyph into a target.
  static const int _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // The dial the sweep turns inside — always drawn, so the glyph keeps its
    // shape when the animation is off.
    canvas.drawCircle(
      centre,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tone.withValues(alpha: 0.22),
    );

    if (still) return;

    // Rings leaving the centre, staggered so one is always young.
    for (var i = 0; i < _rings; i++) {
      final phase = (t + i / _rings) % 1;
      // Ease out: quick off the mark, slowing as it goes — the way a real
      // pulse spreads, and it keeps the outer edge legible for longer.
      final eased = Curves.easeOutCubic.transform(phase);

      canvas.drawCircle(
        centre,
        radius * (0.25 + 0.75 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * (1 - eased) + 0.4
          ..color = tone.withValues(alpha: 0.55 * (1 - eased)),
      );
    }

    // The sweep arm: a wedge of colour trailing the leading edge, brightest at
    // the front, gone by its tail.
    final sweep = Rect.fromCircle(center: centre, radius: radius - 1);
    final start = t * 2 * math.pi - math.pi / 2;

    canvas.drawArc(
      sweep,
      start,
      math.pi / 2.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + math.pi / 2.6,
          colors: [tone.withValues(alpha: 0), tone],
          transform: GradientRotation(start),
        ).createShader(sweep),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.t != t || old.tone != tone || old.still != still;
}


/// The wait, counted down to the second.
///
/// Mrsool's merchant portal quotes an assignment time but its API does not, so
/// the deadline is our own promise (their figure plus headroom) and the clock
/// is honest about that: when it reaches zero it stops counting and says we are
/// still looking, rather than running negative or freezing on 00:00 as though
/// something had gone wrong.
class CourierCountdown extends StatefulWidget {
  const CourierCountdown({
    super.key,
    required this.deadline,
    required this.style,
    this.expiredStyle,
    this.expired,
  });

  final DateTime deadline;
  final TextStyle? style;

  /// Used once the promise has run out. Falls back to [style].
  final TextStyle? expiredStyle;

  /// Shown instead of the default "still looking" sentence once the clock has
  /// run out. The bar passes an empty box: its own headline already says what
  /// is happening, and the sentence would not fit in a pill.
  final Widget? expired;

  @override
  State<CourierCountdown> createState() => _CourierCountdownState();
}

class _CourierCountdownState extends State<CourierCountdown> {
  Timer? _tick;
  late Duration _left = _remaining();

  Duration _remaining() {
    // The wall clock, not a tick count: a phone that slept for five minutes
    // must wake up showing five fewer minutes, not five more ticks owed.
    final left = widget.deadline.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant CourierCountdown old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) {
      _left = _remaining();
      _start();
    }
  }

  void _start() {
    _tick?.cancel();
    if (_left == Duration.zero) return;

    // A countdown is information, not decoration, so it keeps ticking under
    // Reduce Motion. It stops the moment it has nothing left to say.
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _remaining();
      if (!mounted) return;
      setState(() => _left = left);
      if (left == Duration.zero) timer.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left == Duration.zero) {
      return widget.expired ??
          Text(
            L.of(context).liveTrackStillSearching,
            style: widget.expiredStyle ?? widget.style,
            textAlign: TextAlign.center,
          );
    }

    final m = _left.inMinutes;
    final sec = _left.inSeconds % 60;

    return Text(
      // Western digits with a plain colon: a clock is read, not parsed, and
      // this one changes every second — the shape has to stay still.
      '$m:${sec.toString().padLeft(2, '0')}',
      style: widget.style,
      textDirection: TextDirection.ltr,
    );
  }
}
