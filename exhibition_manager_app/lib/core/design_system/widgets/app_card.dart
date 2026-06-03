import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/shadows.dart';
import 'pressable.dart';

/// Modern surface card: soft floating shadow, rounded corners, optional
/// gradient, border and tap (with press-scale). The building block of the
/// refreshed UI — replaces ad-hoc `Container(decoration: …)` cards.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.gradient,
    this.color,
    this.borderColor,
    this.radius = AppRadius.xl,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: br,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow ?? AppShadows.card,
      ),
      child: child,
    );

    final wrapped = margin == null ? card : Padding(padding: margin!, child: card);
    if (onTap == null) return wrapped;
    return Pressable(onTap: onTap, borderRadius: br, child: wrapped);
  }
}
