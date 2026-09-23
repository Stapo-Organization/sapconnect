import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pets/data/household.dart';
import 'characters.dart';

/// The customer's own animal, drawn: the cat for a cat home, the dog for a dog
/// home, the budgie, the fish… Screens name the pose and a designed default;
/// the household decides who plays it.
///
/// A pose whose silhouette the layout depends on (a peek, a nap on a shelf, a
/// sign) is only drawn for the cat and dog; any other species hands those to
/// [fallback].
class Companion extends ConsumerWidget {
  const Companion(
    this.pose, {
    super.key,
    this.fallback = ZbCast.cat,
    this.cast,
    this.height,
    this.width,
    this.flip = false,
    this.idle = ZbIdle.breathe,
    this.entrance = true,
    this.delay = Duration.zero,
  });

  final ZbPose pose;

  /// Who plays the part when the household is unknown.
  final ZbCast fallback;

  /// Forces a cast member, ignoring the household.
  final ZbCast? cast;
  final double? height;
  final double? width;
  final bool flip;
  final ZbIdle idle;
  final bool entrance;
  final Duration delay;

  /// The cast member a pose resolves to for a given household answer.
  static ZbCast resolve(ZbPose pose, ZbCast? household, ZbCast fallback) {
    final who = household ?? fallback;
    final full = who == ZbCast.cat || who == ZbCast.dog;
    if (pose.isStructural && !full) {
      return (fallback == ZbCast.cat || fallback == ZbCast.dog)
          ? fallback
          : ZbCast.cat;
    }
    return who;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final who =
        cast ?? resolve(pose, ref.watch(companionCastProvider), fallback);
    return ZbSticker.cast(
      who,
      pose,
      height: height,
      width: width,
      flip: flip,
      idle: idle,
      entrance: entrance,
      delay: delay,
    );
  }
}
