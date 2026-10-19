import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/notifications/live_activity_service.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import 'splash/splash_plan.dart';
import 'splash/splash_stage.dart';

/// The boot route.
///
/// It does exactly two things — restore the session from the keychain and pick
/// the first destination — then gets out of the way. It deliberately does not
/// wait on the catalog: the home screen has skeletons for that, and a splash
/// that lingers for a network call is a splash the customer resents.
///
/// What the customer *sees* is not drawn here but by [SplashStage], above the
/// navigator: this route only shows the launch picture underneath it, sends
/// the app on while the intro is still playing, and then tells the stage to
/// uncover the destination.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// How long a page transition takes to settle under the stage before the
  /// stage starts to uncover it.
  static const Duration _landing = Duration(milliseconds: 360);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    // The stage outlives this route; hold on to its controller before the
    // route is replaced.
    final splash = ref.read(splashControllerProvider.notifier);
    final plan = ref.read(splashPlanProvider);

    // Leave for the destination a beat before the intro ends, so its page has
    // landed by the time the stage opens onto it. The work runs in parallel.
    final still = context.reduceMotion;
    final handOff = Future<void>.delayed(still ? const Duration(milliseconds: 300) : plan.intro - _landing);

    await ref.read(sessionProvider.notifier).restore();

    // Push comes up alongside the session, never in front of it: it registers
    // the device against whoever just came back, and a build with no Firebase
    // configuration simply does nothing here.
    unawaited(ref.read(pushServiceProvider).start());
    // The lock screen follows the same feed the live bar does; on a phone
    // that cannot show Live Activities this is a no-op.
    unawaited(ref.read(liveActivityServiceProvider).start());

    await handOff;
    if (!mounted) return;

    // The welcome journey owns language, location and notifications; it runs
    // once and hands over to the store.
    final home = ref.read(localStoreProvider).hasSeenWelcome ? '/home' : '/onboarding';
    context.go(home);

    // A notification that woke the app has a destination of its own. It is
    // pushed on top of home rather than replacing it, so «رجوع» lands where
    // the customer expects instead of on an empty stack.
    final tapped = ref.read(pushServiceProvider).pendingRoute;
    if (tapped != null && home == '/home') {
      ref.read(pushServiceProvider).pendingRoute = null;
      unawaited(context.push(tapped));
    }

    await Future<void>.delayed(still ? Duration.zero : _landing);
    // The logo ends in the زوبكسي sign only when it is the sign's page that
    // opens under it.
    splash.leave(flyToSign: home == '/home' && tapped == null);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SplashBackdrop());
}
