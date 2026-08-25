import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The app's motion vocabulary. Durations map onto Material 3's scale; curves
/// follow M3 semantics — `emphasized` for transitions that start and end at
/// rest, `decelerate` for elements entering, `accelerate` for leaving.
///
/// Route every duration through [MotionX.motion] so it collapses to zero under
/// the OS "Reduce Motion" setting instead of needing a guard at each call site.
abstract final class Motion {
  static const Duration pressIn = Duration(milliseconds: 140);
  static const Duration select = Duration(milliseconds: 200);
  static const Duration enter = Duration(milliseconds: 250);
  static const Duration page = Duration(milliseconds: 320);

  /// Per-item offset for staggered list/grid entrances. Above ~50ms a list
  /// starts to feel slow rather than alive.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;

  static const double pressScale = 0.97;
}

extension MotionX on BuildContext {
  /// Whether the OS "Reduce Motion" / "disable animations" setting is on.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Collapses [d] to zero under Reduce Motion.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}

/// Shared-axis page transition for pushing deeper into a hierarchy.
/// Direction-aware, so it slides the correct way in Arabic.
CustomTransitionPage<void> sharedAxisPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.enter,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final dx = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
      final inCurve = CurvedAnimation(parent: animation, curve: Motion.emphasized);
      final outCurve = CurvedAnimation(parent: secondary, curve: Motion.emphasized);
      return SlideTransition(
        position: Tween(begin: Offset(0.10 * dx, 0), end: Offset.zero).animate(inCurve),
        child: FadeTransition(
          opacity: inCurve,
          child: SlideTransition(
            position: Tween(begin: Offset.zero, end: Offset(-0.08 * dx, 0)).animate(outCurve),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Slide-up transition for full-screen modal flows (scanner, wizards).
CustomTransitionPage<void> slideUpPage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.enter,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: Motion.decelerate);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
