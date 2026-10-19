import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import 'picture_store.dart';

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

/// Product imagery: kept on disk by [PictureStore], fading in, and never leaving a raw broken-image
/// icon in a commerce grid. While a photo travels a soft paw holds its place;
/// a photo that does not exist is stood in for by the sleeping cat, which reads
/// as "this picture is napping" rather than as an empty grey box.
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
    this.photo = false,
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
    this.photo = false,
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

  /// A product photograph rather than artwork. In dark mode it sits on
  /// [ZbTokens.photoMatDark] whatever [backgroundColor] says — see there.
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final background = photo && context.isDark
        ? ZbTokens.photoMatDark
        : backgroundColor ??
            (context.isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow);

    Widget missing() => fallback ?? _Missing(background: background);

    Widget image;
    final source = url;
    if (source == null || source.isEmpty) {
      image = missing();
    } else {
      final width = decodeWidth;
      final provider = ZbPicture(source);
      image = Image(
        // Decode to the bucket, not to whatever the store happened to upload.
        image: width == null ? provider : ResizeImage(provider, width: width),
        fit: fit,
        gaplessPlayback: true,
        // The paw sits under the picture and the picture fades over it, so
        // a photo that was already in memory draws at once and one that had
        // to travel eases in.
        frameBuilder: (_, child, frame, sync) {
          if (sync) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (frame == null) _Placeholder(background: background, faded: true),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        // The paw is a polite fallback for the customer and a silent one
        // for us; a build attached to the terminal should still say WHY a
        // picture fell back — the host, the status, the decode.
        errorBuilder: (_, error, _) {
          debugPrint('[img] $source ✗ $error');
          return missing();
        },
      );
    }

    if (padding != null) {
      image = Padding(padding: padding!, child: image);
    }

    final content = ColoredBox(color: background, child: Center(child: image));
    return radius == null ? content : ClipRRect(borderRadius: radius!, child: content);
  }
}

/// No photo at all: the sleeping cat, small and quiet, on the card's ground.
class _Missing extends StatelessWidget {
  const _Missing({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: background,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = (box.biggest.shortestSide * 0.46).clamp(24.0, 96.0);
            return Center(
              child: Opacity(
                opacity: context.isDark ? 0.5 : 0.62,
                child: Image.asset(
                  'assets/characters/cat-sleep.webp',
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                  cacheWidth: 192,
                  excludeFromSemantics: true,
                ),
              ),
            );
          },
        ),
      ),
    );
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
