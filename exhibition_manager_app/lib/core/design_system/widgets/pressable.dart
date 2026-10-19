import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a child with a quiet press feedback (slight dim + scale) + optional haptic.
/// Used by [AppCard], [AppButton] and other tappable surfaces for a modern feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.985,
    this.haptic = true,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      // Shopify-quiet press: a hair of scale plus a dim, not a bounce.
      child: AnimatedOpacity(
        opacity: _down ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
