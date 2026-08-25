import 'package:flutter/services.dart';

/// One vocabulary for touch feedback, so the app feels consistent rather than
/// buzzy. Rule of thumb: [selection] for taps that change a value, [light] for
/// navigation, [success] for a completed commerce action (add to cart, order
/// placed), [warning] when something was refused.
abstract final class Haptics {
  static void selection() => HapticFeedback.selectionClick();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  /// A two-beat tick — the "confetti-light" confirmation used when a product
  /// lands in the cart. Deliberately not a heavy impact: it should read as
  /// satisfying, not alarming.
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static void warning() => HapticFeedback.heavyImpact();
}
