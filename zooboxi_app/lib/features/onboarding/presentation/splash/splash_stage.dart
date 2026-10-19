import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/shelf_tabs.dart' show ShelfBand;
import 'splash_plan.dart';

/// The launch picture, shared by the native launch screens (iOS
/// LaunchScreen.storyboard, Android launch_background + the Android 12 splash
/// icon) and the first Flutter frame: the whole logo, [logoWidth] wide,
/// centred on the whole screen — not the safe area — on the cream canvas by
/// day and graphite by night. Change one and you must change all three.
abstract final class SplashFrame {
  static const String logo = 'assets/brand/logo_full.png';
  static const double logoWidth = 170;
  static const double logoAspect = 1400 / 1204;

  /// The native screens follow the *phone's* appearance, not the in-app theme
  /// toggle, so the splash does too — the app's own theme takes over on home.
  static bool isDark(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  static Color canvas(BuildContext context) => isDark(context) ? ZbTokens.graphite : ZbTokens.cream;
}

/// The native launch picture, drawn by Flutter: what the boot route shows
/// under the stage, and all the stage shows under Reduce Motion.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SplashFrame.canvas(context),
      child: Center(
        child: Image.asset(
          SplashFrame.logo,
          width: SplashFrame.logoWidth,
          height: SplashFrame.logoWidth / SplashFrame.logoAspect,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// Wraps the app and plays the splash above it on a cold start.
///
/// The splash is drawn *over* the navigator rather than as a page in it: the
/// boot route sends the app to its destination while the intro is still on
/// screen, and the stage then uncovers that real screen — an iris for the
/// burst, a lift for the greeting — instead of cutting to a new page.
class SplashStage extends ConsumerWidget {
  const SplashStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gone = ref.watch(splashControllerProvider.select((s) => s.phase == SplashPhase.gone));
    // The same Stack before and after: returning the bare child once the
    // splash is gone would re-parent the navigator and drop its state.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (!gone) const _Stage(),
      ],
    );
  }
}

class _Stage extends ConsumerStatefulWidget {
  const _Stage();

  @override
  ConsumerState<_Stage> createState() => _StageState();
}

class _StageState extends ConsumerState<_Stage> with TickerProviderStateMixin {
  late final SplashPlan _plan = ref.read(splashPlanProvider);

  late final AnimationController _intro = AnimationController(vsync: this, duration: _plan.intro);
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// The idle loop: the rays' slow turn under the burst, a breath for the
  /// greeting's animal. Runs only while the stage is up.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _plan is BurstPlan ? const Duration(seconds: 24) : const Duration(milliseconds: 2600),
  );

  bool _firstFrameHeld = false;
  bool _started = false;
  bool _hapticFired = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    // The native launch screen stays up until Flutter sends its first frame.
    // Hold that frame until the logo is decoded, or the customer sees one
    // empty canvas between two logos — the very flash this splash removes.
    WidgetsBinding.instance.deferFirstFrame();
    _firstFrameHeld = true;
    _intro.addListener(_maybeHaptic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _still = MediaQuery.disableAnimationsOf(context);
    final pictures = <Future<void>>[
      precacheImage(const AssetImage(SplashFrame.logo), context),
      if (_plan case HelloPlan(:final companion))
        precacheImage(AssetImage(_characterAsset(companion.cast)), context),
    ];
    Future.wait(pictures)
        .timeout(const Duration(milliseconds: 900), onTimeout: () => const [])
        .catchError((Object _) => const <void>[])
        .whenComplete(_release);
  }

  void _release() {
    if (_firstFrameHeld) {
      _firstFrameHeld = false;
      WidgetsBinding.instance.allowFirstFrame();
    }
    if (!mounted) return;
    if (_still) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _loop.repeat();
    }
    // A leave that arrived before the pictures were ready is played now.
    if (ref.read(splashControllerProvider).phase == SplashPhase.exit) _playExit();
  }

  void _maybeHaptic() {
    if (_hapticFired) return;
    final at = _plan is BurstPlan ? 300 : 870;
    if (_intro.value * _plan.intro.inMilliseconds >= at) {
      _hapticFired = true;
      _plan is BurstPlan ? Haptics.medium() : Haptics.light();
    }
  }

  bool _exiting = false;

  Future<void> _playExit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    // The intro always finishes its sentence before the way out begins.
    if (_intro.isAnimating) await _intro.forward().orCancel.catchError((Object _) {});
    if (!mounted) return;
    if (_still) {
      _exit.duration = const Duration(milliseconds: 220);
    }
    await _exit.forward().orCancel.catchError((Object _) {});
    if (!mounted) return;
    _loop.stop();
    ref.read(splashControllerProvider.notifier).finish();
  }

  @override
  void dispose() {
    if (_firstFrameHeld) WidgetsBinding.instance.allowFirstFrame();
    _intro.dispose();
    _exit.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(splashControllerProvider.select((s) => s.phase), (_, phase) {
      if (phase == SplashPhase.exit && _started && !_firstFrameHeld) _playExit();
    });
    final flyToSign = ref.watch(splashControllerProvider.select((s) => s.flyToSign));

    final Widget scene;
    if (_still) {
      // Reduce Motion: the launch picture, then a plain fade.
      scene = AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(opacity: 1 - _exit.value, child: child),
        child: const SplashBackdrop(),
      );
    } else {
      final clocks = _Clocks(intro: _intro, exit: _exit, loop: _loop, introMs: _plan.intro.inMilliseconds);
      scene = switch (_plan) {
        BurstPlan() => _BurstScene(clocks: clocks, flyToSign: flyToSign),
        HelloPlan(:final companion) => _HelloScene(clocks: clocks, companion: companion, flyToSign: flyToSign),
      };
    }

    // The stage takes every touch until it is gone: a tap on a half-uncovered
    // home would land on something the customer cannot yet see properly.
    return Semantics(
      container: true,
      label: L.of(context).appName,
      child: ExcludeSemantics(
        child: AbsorbPointer(child: scene),
      ),
    );
  }
}

String _characterAsset(ZbCast cast) => stickerAsset(castStickerKey(cast, ZbPose.wave));

// ─────────────────────────────────────────────────────────────────────────
// Shared timing and geometry
// ─────────────────────────────────────────────────────────────────────────

class _Clocks {
  const _Clocks({required this.intro, required this.exit, required this.loop, required this.introMs});

  final AnimationController intro;
  final AnimationController exit;
  final AnimationController loop;
  final int introMs;

  Listenable get all => Listenable.merge([intro, exit, loop]);

  /// Milliseconds into the intro.
  double get t => intro.value * introMs;

  /// Progress of the intro between [from] and [to] ms, eased by [curve].
  double span(int from, int to, [Curve curve = Curves.linear]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  /// Progress of the exit between the fractions [from] and [to], eased.
  double out(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((exit.value - from) / (to - from)).clamp(0.0, 1.0));
}

/// Screen geometry, scaled from the 390-wide phone the splash was drawn on.
class _Geo {
  _Geo(BuildContext context)
      : size = MediaQuery.sizeOf(context),
        statusTop = MediaQuery.paddingOf(context).top,
        rtl = Directionality.of(context) == TextDirection.rtl;

  final Size size;
  final double statusTop;
  final bool rtl;

  double get u => size.width / 390;
  Offset get center => size.center(Offset.zero);
  double get halfDiagonal => size.shortestSide == 0 ? 0 : math.sqrt(size.width * size.width + size.height * size.height) / 2;

  /// The middle of the زوبكسي storefront sign on home — the end half of the
  /// band both home headers reserve under the status bar.
  Offset get zooboxiSign {
    final half = (size.width - ShelfBand.inset * 2) / 2;
    final x = rtl ? ShelfBand.inset + half / 2 : ShelfBand.inset + half * 1.5;
    return Offset(x, statusTop + ShelfBand.top + ShelfBand.height / 2);
  }
}

/// The whole logo at [center], [scale] × the launch size.
class _Logo extends StatelessWidget {
  const _Logo({required this.center, required this.scale, this.opacity = 1, this.rotation = 0});

  final Offset center;
  final double scale;
  final double opacity;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    const w = SplashFrame.logoWidth;
    const h = SplashFrame.logoWidth / SplashFrame.logoAspect;
    final logo = Image.asset(SplashFrame.logo, width: w, height: h, gaplessPlayback: true);
    return Positioned(
      left: center.dx - w / 2,
      top: center.dy - h / 2,
      width: w,
      height: h,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(angle: rotation, child: Transform.scale(scale: scale, child: logo)),
      ),
    );
  }
}

/// The logo's way out: into the زوبكسي sign when home is what we uncover,
/// otherwise a small lift and fade.
_Logo _leavingLogo(_Clocks c, _Geo g, {required Offset from, required double scale, required bool flyToSign}) {
  if (!flyToSign) {
    return _Logo(
      center: from,
      scale: scale * (1 + 0.22 * c.out(0, 1, Curves.easeOutCubic)),
      // Gone before the screen under it is fully open, so it never sits
      // half-transparent over that screen's own content.
      opacity: 1 - c.out(0, 0.55, Curves.easeInCubic),
    );
  }
  final p = c.out(0, 0.86, Curves.easeInOutCubic);
  final target = g.zooboxiSign;
  return _Logo(
    center: Offset.lerp(from, target, p)!,
    // Shrinks geometrically, so it keeps reading as the same logo moving away
    // rather than one collapsing.
    scale: scale * math.pow(0.15 / scale, p).toDouble(),
    opacity: 1 - c.out(0.72, 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// ج · الانفجار المبهج
// ─────────────────────────────────────────────────────────────────────────

class _Piece {
  const _Piece(this.dx, this.dy, this.size, this.kind, this.color, this.depth, this.rotation);

  /// Where it lands, from the logo's centre, on the 390-wide phone.
  final double dx;
  final double dy;
  final double size;

  /// 's' sparkle · 'h' heart · 'd' dot.
  final String kind;
  final Color color;

  /// 0 far (small, softened) · 1 middle · 2 near.
  final int depth;
  final double rotation;
}

const _cream = ZbTokens.cream;
const _pieces = <_Piece>[
  _Piece(-150, -190, 18, 's', ZbTokens.sparkAmber, 2, 0.7),
  _Piece(140, -210, 14, 's', _cream, 1, -0.5),
  _Piece(170, -40, 20, 'h', ZbTokens.logoCoral, 2, 0.26),
  _Piece(-175, 10, 12, 'd', _cream, 0, 0),
  _Piece(-120, 170, 16, 's', _cream, 1, 1.0),
  _Piece(130, 190, 12, 'd', ZbTokens.sparkAmber, 0, 0),
  _Piece(20, -250, 10, 'd', ZbTokens.coral, 0, 0),
  _Piece(-40, 240, 14, 'h', ZbTokens.logoCoral, 1, -0.35),
  _Piece(185, 110, 10, 'd', _cream, 0, 0),
  _Piece(-190, -90, 22, 's', ZbTokens.sparkAmber, 2, -0.8),
  _Piece(80, -160, 9, 'd', _cream, 0, 0),
  _Piece(-80, -230, 12, 's', ZbTokens.tealTint, 1, 0.35),
  _Piece(60, 230, 20, 's', ZbTokens.sparkAmber, 2, -0.5),
  _Piece(-200, 120, 9, 'd', ZbTokens.sparkAmber, 0, 0),
];

class _BurstScene extends StatelessWidget {
  const _BurstScene({required this.clocks, required this.flyToSign});

  final _Clocks clocks;
  final bool flyToSign;

  /// The logo grows from the launch size to this, about 250 wide.
  static const double _heldScale = 1.47;

  @override
  Widget build(BuildContext context) {
    final dark = SplashFrame.isDark(context);
    final canvas = SplashFrame.canvas(context);
    final ground = dark
        ? const [ZbTokens.tealDark, ZbTokens.tealDeep, Color(0xFF133B3A)]
        : const [Color(0xFF5DB4B1), ZbTokens.teal, ZbTokens.tealDark];

    return AnimatedBuilder(
      animation: clocks.all,
      builder: (context, _) {
        final c = clocks;
        final g = _Geo(context);
        final u = g.u;
        final center = g.center;

        // Anticipation, then the pop: a small dip before it swells past its
        // resting size and settles.
        final dip = c.span(150, 300, Curves.easeOutCubic);
        final pop = c.span(300, 720, Curves.easeOutBack);
        final scale = c.t < 300 ? lerpDouble(1, 0.92, dip)! : lerpDouble(0.92, _heldScale, pop)!;
        final wob = c.span(300, 820);
        final rotation = 0.07 * math.sin(wob * math.pi * 2) * (1 - wob);

        final groundRadius = c.span(240, 760, Curves.easeOutCubic) * (g.halfDiagonal + 40);
        final rays = c.span(420, 1000, Curves.easeOutCubic);
        final glow = c.span(450, 850, Curves.easeOutCubic);
        final fly = c.span(600, 1080, Curves.easeOutCubic);
        final iris = c.out(0, 1, Curves.easeInOutCubic) * (g.halfDiagonal + 60);
        final scatter = c.out(0, 0.9, Curves.easeInCubic);

        final pieces = <Widget>[];
        final far = <Widget>[];
        for (var i = 0; i < _pieces.length; i++) {
          final p = _pieces[i];
          if (c.t < 600) break;
          final reach = 0.35 + 0.65 * fly;
          final float = 5 * u * math.sin(c.loop.value * math.pi * 2 * 6 + i);
          final pos = center + Offset(p.dx * u * reach * (1 + 0.8 * scatter), p.dy * u * reach * (1 + 0.8 * scatter) + float * fly);
          final s = p.size * u * (0.4 + 0.6 * fly);
          final Widget glyph = switch (p.kind) {
            's' => Sparkle(size: s, color: p.color, rotation: p.rotation),
            'h' => Heart(size: s, color: p.color, outline: ZbTokens.inkWarm, rotation: p.rotation),
            _ => DecoratedBox(
                decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                child: SizedBox.square(dimension: s),
              ),
          };
          final placed = Positioned(
            left: pos.dx - s / 2,
            top: pos.dy - s / 2,
            child: Opacity(opacity: (p.depth == 0 ? 0.7 : 1) * (1 - scatter), child: glyph),
          );
          (p.depth == 0 ? far : pieces).add(placed);
        }

        final raysSize = 900 * u;
        final glowSize = 360 * u;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: c.t > 320 || dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Everything but the logo sits behind the iris, which opens on
              // the screen the app has already moved to.
              ClipPath(
                clipper: _IrisClipper(center: center, radius: iris),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: canvas),
                    ClipPath(
                      clipper: _CircleClipper(center: center, radius: groundRadius),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: ground,
                            stops: const [0, 0.42, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: center.dx - raysSize / 2,
                      top: center.dy - raysSize / 2,
                      width: raysSize,
                      height: raysSize,
                      child: Opacity(
                        opacity: rays,
                        child: Transform.rotate(
                          angle: c.loop.value * math.pi * 2 + 0.2 * rays,
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * rays + 0.7 * scatter,
                            child: const CustomPaint(painter: _RaysPainter()),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: center.dx - glowSize / 2,
                      top: center.dy - glowSize / 2,
                      width: glowSize,
                      height: glowSize,
                      child: Opacity(
                        opacity: glow,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * glow,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [_cream.withValues(alpha: 0.62), _cream.withValues(alpha: 0)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Three depths: the far layer softened, so the burst has
                    // air in it instead of lying flat on the ground.
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                      child: Stack(fit: StackFit.expand, children: far),
                    ),
                    ...pieces,
                  ],
                ),
              ),
              if (c.exit.value == 0)
                _Logo(center: center, scale: scale, rotation: rotation)
              else
                _leavingLogo(c, g, from: center, scale: _heldScale, flyToSign: flyToSign),
            ],
          ),
        );
      },
    );
  }
}

/// Cream wedges fanning from the centre and fading out toward the edge.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [_cream.withValues(alpha: 0.22), _cream.withValues(alpha: 0.2), _cream.withValues(alpha: 0)],
        stops: const [0, 0.22, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const count = 16;
    const wedge = math.pi * 2 / count * 0.36;
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: r), a, wedge, false)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) => old.radius != radius || old.center != center;
}

/// Everything except a circle: the hole the burst opens onto the app.
class _IrisClipper extends CustomClipper<Path> {
  const _IrisClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_IrisClipper old) => old.radius != radius || old.center != center;
}

// ─────────────────────────────────────────────────────────────────────────
// د · أهلاً لولو
// ─────────────────────────────────────────────────────────────────────────

class _HelloScene extends StatelessWidget {
  const _HelloScene({required this.clocks, required this.companion, required this.flyToSign});

  final _Clocks clocks;
  final SplashCompanion companion;
  final bool flyToSign;

  static const double _heldScale = 1.24;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = SplashFrame.isDark(context);
    final canvas = SplashFrame.canvas(context);
    final hillColor = dark ? ZbTokens.tealDeep : ZbTokens.teal;
    final kickerColor = dark ? ZbTokens.inkSoftDark : ZbTokens.inkSoft;
    final headlineColor = dark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final text = Theme.of(context).textTheme;

    final kicker = DateTime.now().hour < 12 ? l.splashMorning : l.splashEvening;
    final headline = companion.name.isEmpty ? l.splashWelcomeBack : l.splashPetWaiting(companion.name);
    final twoPoses = companion.cast == ZbCast.cat || companion.cast == ZbCast.dog;

    return AnimatedBuilder(
      animation: clocks.all,
      builder: (context, _) {
        final c = clocks;
        final g = _Geo(context);
        final u = g.u;
        final size = g.size;

        final rise = c.span(150, 600, Curves.easeInOutCubic);
        final logoCenter = Offset(g.center.dx, lerpDouble(g.center.dy, size.height * 0.245, rise)!);
        final logoScale = lerpDouble(1, _heldScale, rise)!;

        final hillW = size.width * 1.64;
        final hillH = 460 * u;
        final hillIn = c.span(300, 760, Curves.easeOutCubic);
        final hillOut = c.out(0, 0.55, Curves.easeInCubic);
        final hillY = size.height * 0.711 + (1 - hillIn) * hillH + hillOut * hillH * 1.1;

        final charH = (twoPoses ? 242 : 200) * u;
        final charTop = size.height * 0.535 + (twoPoses ? 0 : 36 * u);
        final up = c.span(520, 856, Curves.easeOutCubic);
        final settle = c.span(856, 1000, Curves.easeInOutCubic);
        var charDy = c.t < 856 ? lerpDouble(260 * u, -22 * u, up)! : lerpDouble(-22 * u, 0, settle)!;
        final hop = c.out(0, 0.15, Curves.easeOutCubic);
        final drop = c.out(0.15, 0.52, Curves.easeInCubic);
        charDy += -26 * u * hop * (1 - drop) + drop * 480 * u;
        final wave = c.span(1000, 1450);
        final breath = c.t >= c.introMs ? 0.012 * math.sin(c.loop.value * math.pi * 2) : 0.0;
        final charRotation = 0.07 * math.sin(wave * math.pi * 3) * (1 - wave);

        final textOut = 1 - c.out(0, 0.3);
        final kickerIn = c.span(650, 950, Curves.easeOutCubic);
        final headlineIn = c.span(750, 1050, Curves.easeOutCubic);
        // The animal and the hill leave over the canvas first; the canvas goes
        // last, so nothing of the greeting is ever seen over the home.
        final canvasOpacity = 1 - c.out(0.52, 1, Curves.easeInOutCubic);

        final headlineSize = (34 * u).clamp(26.0, 40.0);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: canvasOpacity, child: ColoredBox(color: canvas)),
              Positioned(
                left: (size.width - hillW) / 2,
                top: hillY,
                width: hillW,
                height: hillH,
                child: DecoratedBox(decoration: ShapeDecoration(color: hillColor, shape: const OvalBorder())),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: charTop + charDy,
                height: charH,
                child: Opacity(
                  opacity: c.t >= 520 ? 1 : 0,
                  child: Transform.rotate(
                    angle: charRotation,
                    alignment: const Alignment(0, 0.9),
                    child: Transform.scale(
                      scaleY: 1 + breath,
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(_characterAsset(companion.cast), height: charH, gaplessPlayback: true),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: size.height * 0.408,
                child: Opacity(
                  opacity: kickerIn * textOut,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - kickerIn)),
                    child: Text(
                      kicker,
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(color: kickerColor, fontSize: 17, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: size.height * 0.436,
                child: Opacity(
                  opacity: headlineIn * textOut,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - headlineIn)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        headline,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(
                          color: headlineColor,
                          fontSize: headlineSize,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (c.exit.value == 0)
                _Logo(center: logoCenter, scale: logoScale)
              else
                _leavingLogo(c, g, from: logoCenter, scale: _heldScale, flyToSign: flyToSign),
            ],
          ),
        );
      },
    );
  }
}
