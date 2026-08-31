import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/motion/motion.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/sparkles.dart';

/// The launch screen.
///
/// It does exactly two things — restore the session from the keychain and pick
/// the first destination — then gets out of the way. It deliberately does not
/// wait on the catalog: the home screen has skeletons for that, and a splash
/// that lingers for a network call is a splash the customer resents.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // A floor on the splash so the logo animation reads as intentional
    // rather than as a flash, but the work runs in parallel with it.
    // Long enough for the logo to enter, hop and land — the hop is the app's
    // first word, and half a hop reads as a stutter.
    final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 1400));

    await ref.read(sessionProvider.notifier).restore();
    await minimumSplash;
    if (!mounted) return;

    // The welcome journey owns language, location and notifications; it runs
    // once and hands over to the store.
    context.go(ref.read(localStoreProvider).hasSeenWelcome ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final logoWidth = math.min(MediaQuery.sizeOf(context).width * 0.72, 300.0);
    final side = logoWidth * 1.34;

    final logo = Image.asset(
      'assets/brand/logo_full.png',
      width: logoWidth,
      fit: BoxFit.contain,
    );

    // Enter, then ONE hop: stretch on the way up, squash on the landing,
    // spring back. The sparkles and the hearts are timed to the landing, not
    // to the entrance — the confetti is a reaction to the bounce.
    final animatedLogo = logo
        .animate()
        .fadeIn(duration: 360.ms)
        .scale(
          begin: const Offset(0.82, 0.82),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        )
        .then(delay: 20.ms)
        .moveY(begin: 0, end: -14, duration: 200.ms, curve: Curves.easeOutQuad)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.98, 1.06),
          duration: 200.ms,
          curve: Curves.easeOutQuad,
        )
        .then()
        .moveY(begin: -14, end: 0, duration: 220.ms, curve: Curves.easeInQuad)
        .scale(
          begin: const Offset(0.98, 1.06),
          end: const Offset(1.06, 0.92),
          duration: 220.ms,
          curve: Curves.easeInQuad,
        )
        .then()
        .scale(
          begin: const Offset(1.06, 0.92),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: Motion.spring,
        );

    return Scaffold(
      body: Center(
        child: SizedBox(
          // The sparkle field needs a bounded box to place fractions in; it is
          // padded out around the logo so the confetti orbits rather than
          // overlaps the wordmark.
          width: side,
          height: side,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const SparkleField(sparkles: _splashSparkles, twinkle: true),
              if (reduceMotion) logo else animatedLogo,
              if (!reduceMotion) ...[
                _FloatingHeart(start: side * 0.10, top: side * 0.52, size: 15, delay: 760.ms),
                _FloatingHeart(start: side * 0.83, top: side * 0.46, size: 11, delay: 880.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two little hearts that lift off beside the box as it lands.
class _FloatingHeart extends StatelessWidget {
  const _FloatingHeart({
    required this.start,
    required this.top,
    required this.size,
    required this.delay,
  });

  final double start;
  final double top;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: start,
      top: top,
      child: Heart(size: size, color: ZbTokens.logoCoral)
          .animate()
          .fadeIn(delay: delay, duration: 200.ms)
          .moveY(begin: 0, end: -24, delay: delay, duration: 620.ms, curve: Curves.easeOut)
          .fadeOut(delay: delay + 360.ms, duration: 260.ms),
    );
  }
}

const List<SparkleSpec> _splashSparkles = [
  SparkleSpec(
    dx: 0.13,
    dy: 0.22,
    size: 16,
    color: ZbTokens.sparkAmber,
    delay: Duration(milliseconds: 720),
  ),
  SparkleSpec(
    dx: 0.86,
    dy: 0.17,
    size: 12,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 780),
    rotation: 0.4,
  ),
  SparkleSpec(
    dx: 0.92,
    dy: 0.66,
    size: 18,
    color: ZbTokens.logoCoral,
    delay: Duration(milliseconds: 840),
  ),
  SparkleSpec(
    dx: 0.20,
    dy: 0.78,
    size: 13,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 900),
    rotation: 0.3,
  ),
  SparkleSpec(
    dx: 0.52,
    dy: 0.90,
    size: 10,
    color: ZbTokens.sparkAmber,
    delay: Duration(milliseconds: 940),
  ),
];
