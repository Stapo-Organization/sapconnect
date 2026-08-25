import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../utils/haptics.dart';

/// A tappable surface with the app's press feel: a ripple, an instant
/// scale-down on touch, and a haptic tick.
///
/// Use it for surfaces that don't already own an [InkWell] — cards, chips,
/// tiles. It clears cleanly when a press turns into a scroll, and under Reduce
/// Motion it keeps the tap and haptic while dropping the scale.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.scale = Motion.pressScale,
    this.haptic = Haptics.selection,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double scale;

  /// Fired once on press-down. Pass `null` for silent surfaces.
  final VoidCallback? haptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final pressed = _down && enabled && !context.reduceMotion;

    return AnimatedScale(
      scale: pressed ? widget.scale : 1.0,
      duration: Motion.pressIn,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: widget.borderRadius == null ? Clip.none : Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: widget.borderRadius,
          onTapDown: enabled && widget.haptic != null ? (_) => widget.haptic!() : null,
          onHighlightChanged: enabled ? (v) => setState(() => _down = v) : null,
          child: widget.child,
        ),
      ),
    );
  }
}
