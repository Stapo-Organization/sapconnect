import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';

part 'sticker_table.g.dart';

/// The drawn cast. Cat and dog carry the full wardrobe of poses; the others
/// were drawn once, in one pose, and wear it everywhere.
enum ZbCast { cat, dog, budgie, fish, hamster, rabbit, turtle }

/// What a character is doing. The pose is chosen for what the screen asks of
/// the customer next — pointing at a suggestion, delighted by a heart, asleep
/// while إكسبريس is closed — never for decoration.
enum ZbPose {
  sitUp('sit-up'),
  wave('wave'),
  wow('wow'),
  lie('lie'),
  sleep('sleep'),
  peek('peek'),
  peekSide('peek-side'),
  present('present'),
  point('point'),
  celebrate('celebrate'),
  run('run'),
  sign('sign');

  const ZbPose(this.key);

  final String key;

  /// Poses whose silhouette the layout depends on — a peek hides behind an
  /// edge, a lie rests on a shelf, a sign carries text. A one-pose species
  /// cannot stand in for these, so they fall back to the cat or dog.
  bool get isStructural => switch (this) {
    ZbPose.lie ||
    ZbPose.sleep ||
    ZbPose.peek ||
    ZbPose.peekSide ||
    ZbPose.run ||
    ZbPose.sign => true,
    _ => false,
  };
}

/// The glossy props drawn in the same hand as the cast.
enum ZbProp {
  confetti('confetti-burst'),
  heart('heart-glossy'),
  hearts('hearts-cluster'),
  sparkles('sparkle-burst');

  const ZbProp(this.key);

  final String key;
}

/// A baked sticker's pixel size and its art box (fractions of the sticker).
@immutable
class StickerArt {
  const StickerArt(
    this.width,
    this.height,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );

  final int width;
  final int height;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get artAspect => ((right - left) * width) / ((bottom - top) * height);
}

/// The asset key for a cast member in a pose.
String castStickerKey(ZbCast cast, ZbPose pose) => switch (cast) {
  ZbCast.cat => 'cat-${pose.key}',
  ZbCast.dog => 'dog-${pose.key}',
  ZbCast.budgie => 'budgie',
  ZbCast.fish => 'fish',
  ZbCast.hamster => 'hamster',
  ZbCast.rabbit => 'rabbit',
  ZbCast.turtle => 'turtle',
};

String stickerAsset(String key) => 'assets/characters/$key.webp';

StickerArt stickerArt(String key) => _stickers[key]!;

/// How a character keeps living after it arrives. Each is a small loop — a
/// still mascot reads as a frozen frame, a busy one asks to be looked at.
enum ZbIdle { none, breathe, sleep, hop, peek, float }

/// One sticker, laid out by its art box.
///
/// [height] is the height of the *art* — the ring spills outside the box, so
/// a character given `bottom: 0` stands exactly on the line below it.
class ZbSticker extends StatefulWidget {
  const ZbSticker(
    this.stickerKey, {
    super.key,
    this.height,
    this.width,
    this.flip = false,
    this.idle = ZbIdle.breathe,
    this.entrance = true,
    this.delay = Duration.zero,
  }) : assert(height != null || width != null, 'a sticker needs a size');

  ZbSticker.cast(
    ZbCast cast,
    ZbPose pose, {
    Key? key,
    double? height,
    double? width,
    bool flip = false,
    ZbIdle idle = ZbIdle.breathe,
    bool entrance = true,
    Duration delay = Duration.zero,
  }) : this(
         castStickerKey(cast, pose),
         key: key,
         height: height,
         width: width,
         flip: flip,
         idle: idle,
         entrance: entrance,
         delay: delay,
       );

  ZbSticker.prop(
    ZbProp prop, {
    Key? key,
    double? height,
    double? width,
    ZbIdle idle = ZbIdle.none,
    bool entrance = true,
    Duration delay = Duration.zero,
  }) : this(
         prop.key,
         key: key,
         height: height,
         width: width,
         idle: idle,
         entrance: entrance,
         delay: delay,
       );

  final String stickerKey;
  final double? height;
  final double? width;

  /// Mirrors the art — a peek that has to lean in from the other edge.
  final bool flip;
  final ZbIdle idle;

  /// A short pop on arrival (under 400 ms). Off where the sticker is part of
  /// a list that rebuilds while scrolling.
  final bool entrance;
  final Duration delay;

  /// The art box this sticker takes at a given height or width.
  static Size sizeOf(String key, {double? height, double? width}) {
    final art = stickerArt(key);
    if (height != null) return Size(height * art.artAspect, height);
    final w = width!;
    return Size(w, w / art.artAspect);
  }

  @override
  State<ZbSticker> createState() => _ZbStickerState();
}

class _ZbStickerState extends State<ZbSticker> with TickerProviderStateMixin {
  AnimationController? _loop;
  AnimationController? _in;

  static const Duration _restAfter = Duration(seconds: 12);

  Duration get _period => switch (widget.idle) {
    ZbIdle.breathe => const Duration(milliseconds: 3200),
    ZbIdle.sleep => const Duration(milliseconds: 3800),
    ZbIdle.hop => const Duration(milliseconds: 420),
    ZbIdle.peek => const Duration(milliseconds: 4500),
    ZbIdle.float => const Duration(milliseconds: 3600),
    ZbIdle.none => Duration.zero,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = context.reduceMotion;
    if (still) {
      _loop?.stop();
      _in?.value = 1;
      return;
    }
    if (widget.entrance && _in == null) {
      _in = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
      Future<void>.delayed(widget.delay, () {
        if (mounted) _in!.forward();
      });
    }
    if (widget.idle != ZbIdle.none && _loop == null) {
      // Alive for a while, then at rest: a character that never stops moving
      // asks to be looked at, and keeps the screen repainting for nothing.
      // Every loop ends where it began, so it settles without a jump.
      final cycles = (_restAfter.inMilliseconds / _period.inMilliseconds).ceil();
      _loop = AnimationController(vsync: this, duration: _period)..repeat(count: cycles);
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    _in?.dispose();
    super.dispose();
  }

  Matrix4 _idle(double t) {
    final s = math.sin(2 * math.pi * t);
    return switch (widget.idle) {
      ZbIdle.breathe =>
        Matrix4.identity()
          ..translateByDouble(0, -1.2 * (s + 1) / 2, 0, 1)
          ..scaleByDouble(
            1 + 0.012 * (s + 1) / 2,
            1 - 0.01 * (s + 1) / 2,
            1,
            1,
          ),
      ZbIdle.sleep =>
        Matrix4.identity()..scaleByDouble(
          1 + 0.02 * (s + 1) / 2,
          1 + 0.035 * (s + 1) / 2,
          1,
          1,
        ),
      ZbIdle.hop =>
        Matrix4.identity()..translateByDouble(0, -3.5 * (s + 1) / 2, 0, 1),
      // A lean out and back every few seconds, then stillness.
      ZbIdle.peek =>
        Matrix4.identity()..translateByDouble(
          t > 0.7 && t < 0.9 ? -4 * math.sin((t - 0.7) / 0.2 * math.pi) : 0,
          0,
          0,
          1,
        ),
      ZbIdle.float =>
        Matrix4.identity()
          ..translateByDouble(0, -7 * (s + 1) / 2, 0, 1)
          ..rotateZ((-8 + 5 * (s + 1) / 2) * math.pi / 180),
      ZbIdle.none => Matrix4.identity(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final art = stickerArt(widget.stickerKey);
    final box = ZbSticker.sizeOf(
      widget.stickerKey,
      height: widget.height,
      width: widget.width,
    );
    final artW = art.right - art.left;
    final artH = art.bottom - art.top;
    final stickerW = box.width / artW;
    final stickerH = box.height / artH;

    Widget image = Image.asset(
      stickerAsset(widget.stickerKey),
      width: stickerW,
      height: stickerH,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );

    final loop = _loop;
    if (loop != null) {
      image = AnimatedBuilder(
        animation: loop,
        builder: (context, child) => Transform(
          alignment: widget.idle == ZbIdle.float
              ? Alignment.center
              : Alignment.bottomCenter,
          transform: _idle(loop.value),
          child: child,
        ),
        child: image,
      );
    }
    final enter = _in;
    if (enter != null) {
      final curve = CurvedAnimation(parent: enter, curve: Motion.spring);
      image = FadeTransition(
        opacity: CurvedAnimation(parent: enter, curve: const Interval(0, 0.5)),
        child: ScaleTransition(
          scale: Tween(begin: 0.86, end: 1.0).animate(curve),
          alignment: Alignment.bottomCenter,
          child: image,
        ),
      );
    }

    // The sticker hangs off its art box on every side by the width of its
    // ring; the box is what the layout sees.
    Widget out = SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -art.left * stickerW,
            top: -art.top * stickerH,
            width: stickerW,
            height: stickerH,
            child: image,
          ),
        ],
      ),
    );
    if (widget.flip) {
      out = Transform.flip(flipX: true, child: out);
    }
    return ExcludeSemantics(child: RepaintBoundary(child: out));
  }
}

/// A soft contact shadow for a character to stand on.
class ZbGround extends StatelessWidget {
  const ZbGround({
    super.key,
    required this.width,
    this.height = 16,
    this.opacity = 0.13,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              const Color(0xFF2C3E2D).withValues(alpha: opacity),
              const Color(0x002C3E2D),
            ],
          ),
          borderRadius: BorderRadius.all(
            Radius.elliptical(width / 2, height / 2),
          ),
        ),
      ),
    );
  }
}

/// The cat or dog holding up its blank board, with [text] written on it —
/// a pet's name as it is typed, a chapter title. The board's place inside
/// the art was measured from the drawing (its centre, size and slight tilt).
class SignHolder extends StatelessWidget {
  const SignHolder({super.key, required this.cast, required this.text, required this.height});

  /// The cat or the dog — the only two drawn holding a sign.
  final ZbCast cast;
  final String text;
  final double height;

  // centre x, centre y, width, height — fractions of the art box.
  static const _board = {
    ZbCast.cat: (0.488, 0.168, 0.773, 0.226),
    ZbCast.dog: (0.500, 0.151, 0.790, 0.195),
  };

  @override
  Widget build(BuildContext context) {
    final who = cast == ZbCast.dog ? ZbCast.dog : ZbCast.cat;
    final key = castStickerKey(who, ZbPose.sign);
    final box = ZbSticker.sizeOf(key, height: height);
    final (cx, cy, bw, bh) = _board[who]!;
    final w = box.width * bw;
    final h = box.height * bh;
    return SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ZbSticker(key, height: height),
          Positioned(
            left: box.width * cx - w / 2,
            top: box.height * cy - h / 2,
            width: w,
            height: h,
            child: Transform.rotate(
              angle: -3 * math.pi / 180,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08, vertical: h * 0.12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xFF5A2C2F),
                      fontWeight: FontWeight.w900,
                      fontSize: h * 0.62,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
