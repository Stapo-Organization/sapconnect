import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zooboxi_tokens.dart';
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
    final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 1100));

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

    final logo = Image.asset(
      'assets/brand/logo_full.png',
      width: logoWidth,
      fit: BoxFit.contain,
    );

    return Scaffold(
      body: Center(
        child: SizedBox(
          // The sparkle field needs a bounded box to place fractions in; it is
          // padded out around the logo so the confetti orbits rather than
          // overlaps the wordmark.
          width: logoWidth * 1.34,
          height: logoWidth * 1.34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SparkleField(sparkles: _splashSparkles, twinkle: true),
              if (reduceMotion)
                logo
              else
                logo
                    .animate()
                    .scale(
                      begin: const Offset(0.82, 0.82),
                      end: const Offset(1, 1),
                      duration: 620.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

const List<SparkleSpec> _splashSparkles = [
  SparkleSpec(
    dx: 0.13,
    dy: 0.22,
    size: 16,
    color: ZbTokens.sparkAmber,
    delay: Duration(milliseconds: 120),
  ),
  SparkleSpec(
    dx: 0.86,
    dy: 0.17,
    size: 12,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 200),
    rotation: 0.4,
  ),
  SparkleSpec(
    dx: 0.92,
    dy: 0.66,
    size: 18,
    color: ZbTokens.logoCoral,
    delay: Duration(milliseconds: 280),
  ),
  SparkleSpec(
    dx: 0.20,
    dy: 0.78,
    size: 13,
    color: ZbTokens.logoTeal,
    delay: Duration(milliseconds: 350),
    rotation: 0.3,
  ),
  SparkleSpec(
    dx: 0.52,
    dy: 0.90,
    size: 10,
    color: ZbTokens.sparkAmber,
    delay: Duration(milliseconds: 420),
  ),
];
