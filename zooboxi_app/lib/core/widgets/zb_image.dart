import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';

/// How wide an image is decoded, in device pixels.
///
/// A photo the store serves at 1000px costs ~4 MB of memory whatever size it is
/// drawn at, because the decode happens before the layout does. Capping the
/// decode is the largest and least visible saving available: a 150pt card on a
/// 3x screen needs 450 real pixels and was being handed 1000.
///
/// There are deliberately only a HANDFUL of buckets, and every surface that
/// shows the same picture uses the same one. The decode width is part of the
/// image cache key, so a per-surface value would decode the same photo once for
/// the rail, again for the cart line and again for the order chip — three
/// copies of one picture, which is worse than the problem. A small surface
/// takes the card bucket and scales down while painting; that is free.
abstract final class ZbDecode {
  /// Everything that draws a product photo at card size or smaller: rails,
  /// grids, cart lines, order chips, care rows, the live-order thumbnail.
  /// 160pt at 3x, with room for the widest card.
  static const int card = 480;

  /// Surfaces that genuinely fill the width: bundle collages, brand tiles.
  static const int wide = 800;

  /// Full-bleed artwork — hero slides, campaign banners, the product gallery.
  /// One at a time, and the whole point of them is that they are big.
  static const int hero = 1200;

  /// Small round marks: pet avatars, brand chips, category glyphs.
  static const int chip = 192;
}

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
    this.fallback,
    this.decodeWidth = ZbDecode.card,
  });

  /// A surface that must not cap its decode at all: the product gallery, whose
  /// whole purpose is that the customer can pinch it to 3.6x and read the
  /// ingredients off the back of the bag. Capping that would trade a real
  /// feature for memory the gallery does not hold for long — it draws one
  /// picture at a time.
  const ZbImage.full({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.radius,
    this.backgroundColor,
    this.padding,
    this.fallback,
  }) : decodeWidth = null;

  final String? url;
  final BoxFit fit;
  final BorderRadius? radius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  /// The bucket this surface decodes at — see [ZbDecode]. Null means decode at
  /// full size, which only the zoomable gallery needs. Width only: passing a
  /// height as well makes `ResizeImage` honour both numbers and ignore the
  /// source aspect ratio, which stretches the picture.
  final int? decodeWidth;

  /// Shown instead of the paw when there is no image, or when the one there is
  /// fails to load. Categories pass their emoji here: a cat is a better
  /// stand-in for a cat than a generic mark is.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final background = backgroundColor ??
        (context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow);

    Widget missing() =>
        fallback ?? _Placeholder(background: background);

    Widget image;
    final source = url;
    if (source == null || source.isEmpty) {
      image = missing();
    } else {
      image = CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        // Decode to the bucket, not to whatever the store happened to upload.
        memCacheWidth: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => _Placeholder(background: background, faded: true),
        errorWidget: (_, _, _) => missing(),
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
