import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import 'zb_image.dart';

/// Category artwork — the commissioned photo when the server has one, its
/// emoji when it doesn't.
///
/// The emoji is not a consolation prize. In a pet store 🐱 is the fastest
/// possible read of "cats", so it gets the same tinted well the photograph
/// sits in rather than a broken-image grey — and it never scales with the OS
/// text size, because an emoji here is a picture, not a word.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.image,
    required this.size,
    this.icon,
    this.circular = true,
    this.borderRadius = ZbTokens.rMd,
    this.fit = BoxFit.cover,
    this.padding,
  });

  final String? image;
  final String? icon;
  final double size;

  /// Circles for the animal roots, rounded squares for everything below them.
  final bool circular;
  final double borderRadius;
  final BoxFit fit;

  /// Illustrated tiles are drawn on white and want breathing room; the
  /// photographic roots are cropped edge to edge and want none.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final emoji = icon;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: context.isDark ? 0.34 : 0.5),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(borderRadius),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ZbImage(
        url: image,
        fit: fit,
        padding: padding,
        backgroundColor: Colors.transparent,
        fallback: emoji == null
            ? null
            : Center(
                child: Text(
                  emoji,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: size * 0.44),
                ),
              ),
      ),
    );
  }
}
