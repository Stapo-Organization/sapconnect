import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';

/// Product imagery: cached, fading in, and never leaving a raw broken-image
/// icon in a commerce grid. Missing art falls back to a soft paw mark, which
/// reads as "no photo yet" rather than "the app is broken".
class ZbImage extends StatelessWidget {
  const ZbImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.radius,
    this.backgroundColor,
    this.padding,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? radius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final background = backgroundColor ??
        (context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow);

    Widget image;
    final source = url;
    if (source == null || source.isEmpty) {
      image = _Placeholder(background: background);
    } else {
      image = CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => _Placeholder(background: background, faded: true),
        errorWidget: (_, _, _) => _Placeholder(background: background),
      );
    }

    if (padding != null) {
      image = Padding(padding: padding!, child: image);
    }

    final content = ColoredBox(color: background, child: Center(child: image));
    return radius == null ? content : ClipRRect(borderRadius: radius!, child: content);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.background, this.faded = false});

  final Color background;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SizedBox.expand(
      child: ColoredBox(
        color: background,
        child: Center(
          child: Icon(
            Icons.pets_rounded,
            size: 28,
            color: cs.onSurfaceVariant.withValues(alpha: faded ? 0.14 : 0.26),
          ),
        ),
      ),
    );
  }
}
