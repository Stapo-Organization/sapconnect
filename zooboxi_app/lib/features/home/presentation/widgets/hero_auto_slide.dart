import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';

// The hero slides the server composes when there is no bought banner to show.
// It ships copy plus a handful of product photos and lets the app draw them,
// so a "delivered in two hours" slide is the same object in both languages,
// both themes and at any text size — and costs a designer nothing.
//
// The composition rules are the ones ad designers use: copy block vertically
// centered on the reading side, artwork anchored to the far bottom corner and
// deliberately cropped by the slide edge (a full object floating in space
// reads as clip-art; a cropped one reads as a scene), and one quiet layer of
// decoration for depth.

/// Paint recipe for a server-composed slide. One per theme, so "express" looks
/// like the express promise everywhere it appears rather than like a generic
/// gradient with different words on it.
@immutable
class AutoSlideSkin {
  const AutoSlideSkin({
    required this.gradient,
    required this.fg,
    required this.muted,
    required this.accent,
  });

  final LinearGradient gradient;
  final Color fg;
  final Color muted;

  /// The deep theme color used for strokes on *white* — the badge text, the
  /// bolt inside its disc.
  final Color accent;

  static AutoSlideSkin of(BuildContext context, String? theme) {
    final zb = context.zb;
    final dark = context.isDark;
    final onDark = dark ? ZbTokens.inkDark : Colors.white;

    return switch (theme) {
      'express' => AutoSlideSkin(
          gradient: dark
              ? const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.tealContainerDark, ZbTokens.graphiteHigh],
                )
              : const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.tealDeep, ZbTokens.tealDark],
                ),
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          accent: ZbTokens.tealDeep,
        ),
      'clearance' => AutoSlideSkin(
          gradient: dark
              ? const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.coralContainerDark, ZbTokens.graphiteHigh],
                )
              : const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [ZbTokens.coralDark, ZbTokens.coral],
                ),
          fg: onDark,
          muted: onDark.withValues(alpha: 0.82),
          accent: ZbTokens.coralDark,
        ),
      // A brand slide belongs to the brand: a deep neutral stage, the logo on
      // its own white tile carrying the identity — the same reason the brand
      // strip refuses to tint itself. Deep, because this gradient doubles as
      // the hero canvas and the header on top of it is always light.
      'brand' => AutoSlideSkin(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [ZbTokens.graphiteHighest, ZbTokens.graphiteHigh],
          ),
          fg: ZbTokens.inkDark,
          muted: ZbTokens.inkDark.withValues(alpha: 0.75),
          accent: ZbTokens.graphiteHighest,
        ),
      _ => AutoSlideSkin(
          gradient: zb.brandGradient,
          fg: onDark,
          muted: onDark.withValues(alpha: 0.85),
          accent: ZbTokens.tealDeep,
        ),
    };
  }
}

class HeroAutoCard extends StatelessWidget {
  const HeroAutoCard({super.key, required this.slide, this.flush = false});

  final HeroSlide slide;

  /// True when the slide sits on the hero canvas, which already painted this
  /// skin's gradient from the status bar down — paint everything but it.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final skin = AutoSlideSkin.of(context, slide.theme);
    final images = slide.productImages.take(3).toList();
    final logo = slide.theme == 'brand' ? slide.brand?.logo : null;
    final ranked = slide.theme == 'bestsellers';

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      final Widget? art;
      if (logo != null) {
        art = _BrandTile(logo: logo);
      } else if (images.isNotEmpty) {
        art = _ProductCascade(images: images, ranked: ranked, slideHeight: h);
      } else if (slide.theme == 'express') {
        art = _ExpressMotif(skin: skin);
      } else {
        art = null;
      }

      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (!flush) DecoratedBox(decoration: BoxDecoration(gradient: skin.gradient)),
          _DecorLayer(fg: skin.fg, slideHeight: h),

          // Artwork owns the END-bottom corner and is cropped by the slide
          // edge on purpose — the outer canvas clip finishes the crop.
          if (art != null)
            PositionedDirectional(
              end: logo != null ? 16 : -10,
              bottom: logo != null ? (h - 116) / 2 : -12,
              child: art,
            ),

          // Copy: vertically centered on the reading side.
          PositionedDirectional(
            start: 20,
            top: 0,
            bottom: 6,
            width: w * (art == null ? 0.78 : 0.55),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((slide.badge ?? '').isNotEmpty) ...[
                  _SlideBadge(label: slide.badge!, accent: skin.accent),
                  Gap.h8,
                ],
                if ((slide.title ?? '').isNotEmpty)
                  Flexible(
                    child: Text(
                      slide.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.headlineSmall?.copyWith(
                        color: skin.fg,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                if ((slide.subtitle ?? '').isNotEmpty) ...[
                  Gap.h4,
                  Flexible(
                    child: Text(
                      slide.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyMedium?.copyWith(
                        color: skin.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                  Gap.h16,
                  CampaignCta(label: slide.ctaLabel!),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// The white pill with the number that earns the slide its place —
/// "خصم حتى 45%" in the theme's own deep color.
class _SlideBadge extends StatelessWidget {
  const _SlideBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: context.tt.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// One quiet layer of depth behind everything: a big off-canvas ring and a
/// few bright specks. Enough that the color field isn't flat, never enough
/// to compete with the copy.
class _DecorLayer extends StatelessWidget {
  const _DecorLayer({required this.fg, required this.slideHeight});

  final Color fg;
  final double slideHeight;

  @override
  Widget build(BuildContext context) {
    final ring = slideHeight * 1.35;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          end: -ring * 0.32,
          top: -ring * 0.38,
          child: Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: fg.withValues(alpha: 0.08), width: 1.6),
            ),
          ),
        ),
        for (final (dx, dy, size) in const [(0.46, 0.18, 5.0), (0.54, 0.72, 3.5), (0.40, 0.50, 4.0)])
          PositionedDirectional(
            start: MediaQuery.sizeOf(context).width * dx,
            top: slideHeight * dy,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: 0.35),
              ),
            ),
          ),
      ],
    );
  }
}

/// The express promise as a mark: pulse rings around a bright disc with the
/// same bolt the promise chip wears — the visual it already trained.
class _ExpressMotif extends StatelessWidget {
  const _ExpressMotif({required this.skin});

  final AutoSlideSkin skin;

  @override
  Widget build(BuildContext context) {
    const outer = 196.0;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (size, alpha, width) in const [(196.0, 0.10, 1.5), (150.0, 0.16, 1.5)])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: skin.fg.withValues(alpha: alpha), width: width),
              ),
            ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.bolt_rounded, size: 52, color: skin.accent),
          ),
        ],
      ),
    );
  }
}

/// The brand's mark on its own white tile: brand logos are drawn for light
/// paper, and the stage behind them is deep.
class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.logo});

  final String logo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 116,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ZbImage(url: logo, backgroundColor: Colors.transparent),
    );
  }
}

/// Product photos as a diagonal cascade of ringed circles falling into the
/// slide's corner — biggest nearest the customer's thumb, each one white-ringed
/// and shadowed so it sits *on* the color instead of dissolving into it.
/// [ranked] pins 1·2·3 medals on them, which is what "best sellers" means.
class _ProductCascade extends StatelessWidget {
  const _ProductCascade({
    required this.images,
    required this.ranked,
    required this.slideHeight,
  });

  final List<String> images;
  final bool ranked;
  final double slideHeight;

  @override
  Widget build(BuildContext context) {
    final big = (slideHeight * 0.56).clamp(88.0, 124.0);
    final sizes = [big, big * 0.82, big * 0.68];
    // (end, bottom) anchors: a diagonal from the corner up toward the copy.
    final anchors = [
      (0.0, 0.0),
      (big * 0.78, big * 0.52),
      (big * 0.22, big * 1.02),
    ];

    final count = images.length.clamp(0, 3);
    final width = big + (count > 1 ? anchors[1].$1 + sizes[1] * 0.4 : 0);
    final height = big + (count > 2 ? anchors[2].$2 : (count > 1 ? anchors[1].$2 : 0));

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = count - 1; i >= 0; i--)
            PositionedDirectional(
              end: anchors[i].$1,
              bottom: anchors[i].$2,
              child: _RingedProduct(
                url: images[i],
                size: sizes[i],
                rank: ranked ? i + 1 : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingedProduct extends StatelessWidget {
  const _RingedProduct({required this.url, required this.size, this.rank});

  final String url;
  final double size;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: ZbImage(url: url, fit: BoxFit.cover, backgroundColor: Colors.white),
          ),
        ),
        if (rank != null)
          PositionedDirectional(
            top: -2,
            start: -2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZbTokens.amber,
                boxShadow: [
                  BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                '$rank',
                style: context.tt.labelSmall?.copyWith(
                  color: ZbTokens.ink,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
