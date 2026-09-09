import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'hero_carousel.dart' show autoSlideRoute;
import 'link_navigation.dart';

/// إكسبريس gets offers, not a hero.
///
/// زوبكسي opens on a full-bleed canvas: the header fused into it, the slide
/// running behind the status bar, the whole first screen given to one picture.
/// That is a shop window, and it is right for a store someone came to browse.
/// The dark store cannot afford that screen — every row spent on a picture is
/// a row not spent on the errand.
///
/// What it can afford is a strip of cards a thumb's swipe wide with the next
/// already peeking, and that shape only earns its place if it is made
/// properly: light grounds drawn from the brand's own tints rather than a
/// dark slab, a colour per theme so the express clock and the new arrivals
/// are told apart before a word is read, and motion that answers the finger
/// instead of running on a timer.
class ExpressOfferSlider extends StatefulWidget {
  const ExpressOfferSlider({super.key, required this.slides});

  final List<HeroSlide> slides;

  /// A strip with nothing to put in it renders nothing at all.
  static bool hasContent(List<HeroSlide> slides) => slides.any(
    (s) => (s.title ?? '').isNotEmpty || (s.bestImage ?? '').isNotEmpty,
  );

  /// The next card peeks, which is the whole invitation to swipe.
  static const double _viewport = 0.90;

  static const double _maxTextScale = 1.3;

  /// Live copy sets the height, exactly as it does on the product card and
  /// the banner: computed from the clamped text scale so 1.3× grows the box
  /// instead of clipping the second line.
  static double cardHeight(BuildContext context) {
    final double factor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: _maxTextScale).scale(16) /
        16;
    return 152 + (factor - 1) * 54;
  }

  @override
  State<ExpressOfferSlider> createState() => _ExpressOfferSliderState();
}

class _ExpressOfferSliderState extends State<ExpressOfferSlider> {
  late final PageController _pages = PageController(
    viewportFraction: ExpressOfferSlider._viewport,
  );

  /// Drives the dots. Only the whole page matters to them, so this rebuilds
  /// once per card rather than once per frame of the swipe.
  int _settled = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// How far this card is from the middle of the viewport, in pages.
  ///
  /// Null before the first layout, when the controller has no dimensions yet
  /// — every card then draws at rest, which is exactly the first frame we
  /// want anyway.
  double _offsetOf(int index) {
    if (!_pages.hasClients || _pages.position.hasContentDimensions != true) {
      return index == 0 ? 0 : 1;
    }
    return ((_pages.page ?? _pages.initialPage.toDouble()) - index).clamp(
      -1.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<HeroSlide> slides = widget.slides;
    if (!ExpressOfferSlider.hasContent(slides)) return const SizedBox.shrink();

    final bool still = context.reduceMotion;
    final double height = ExpressOfferSlider.cardHeight(context);

    final Widget strip = SizedBox(
      height: height,
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: slides.length,
        onPageChanged: (page) {
          if (page != _settled) setState(() => _settled = page);
        },
        itemBuilder: (context, index) {
          final Widget card = _OfferCard(
            slide: slides[index],
            palette: _OfferPalette.of(context, slides[index], index),
          );
          if (still) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 5),
              child: card,
            );
          }
          // The card answers the finger: it settles into place as it reaches
          // the middle and steps back as it leaves. Rebuilt from the
          // controller, so there is no timer and nothing animates while the
          // page sits still.
          return AnimatedBuilder(
            animation: _pages,
            builder: (context, child) {
              final double delta = _offsetOf(index);
              final double away = delta.abs();
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 5),
                child: Transform.translate(
                  offset: Offset(0, away * 7),
                  child: Transform.scale(
                    scale: 1 - away * 0.055,
                    child: Opacity(opacity: 1 - away * 0.26, child: child),
                  ),
                ),
              );
            },
            child: card,
          );
        },
      ),
    );

    if (slides.length < 2) return strip;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        strip,
        const SizedBox(height: 10),
        _Dots(count: slides.length, index: _settled, still: still),
      ],
    );
  }
}

/// A light ground, an ink that reads on it, and one accent for the call to
/// action — chosen by what the slide is ABOUT, not by where it landed.
///
/// The clock slide is ember, the branch's bestsellers are teal, new arrivals
/// amber, a price cut coral. So the colour is already telling the customer
/// something before the headline is read, and the strip stays varied without
/// looking randomised.
@immutable
class _OfferPalette {
  const _OfferPalette({
    required this.ground,
    required this.ink,
    required this.accent,
    required this.onAccent,
  });

  final Color ground;
  final Color ink;
  final Color accent;

  /// What reads ON [accent]. In the light themes the accent is deep and takes
  /// white; in the dark ones it is a pale tint and white on it is a smudge, so
  /// the call to action carries the card's own ground instead.
  final Color onAccent;

  static const List<_OfferPalette> _light = [
    // ember
    _OfferPalette(
      ground: ZbTokens.expressBg,
      ink: Color(0xFF7C2D07),
      accent: ZbTokens.expressFg,
      onAccent: Colors.white,
    ),
    // teal
    _OfferPalette(
      ground: ZbTokens.tealTint,
      ink: ZbTokens.tealDeep,
      accent: ZbTokens.tealDark,
      onAccent: Colors.white,
    ),
    // amber
    _OfferPalette(
      ground: Color(0xFFFFF4DC),
      ink: Color(0xFF75540A),
      accent: Color(0xFFB07C14),
      onAccent: Colors.white,
    ),
    // coral
    _OfferPalette(
      ground: Color(0xFFFCE9E4),
      ink: Color(0xFF8A3728),
      accent: ZbTokens.coralDark,
      onAccent: Colors.white,
    ),
  ];

  static const List<_OfferPalette> _dark = [
    _OfferPalette(
      ground: ZbTokens.expressBgDark,
      ink: Color(0xFFFFD3B4),
      accent: ZbTokens.expressFgDark,
      onAccent: Color(0xFF3B2116),
    ),
    _OfferPalette(
      ground: ZbTokens.tealContainerDark,
      ink: Color(0xFFB3E2E0),
      accent: ZbTokens.tealOnDark,
      onAccent: Color(0xFF12312F),
    ),
    _OfferPalette(
      ground: Color(0xFF3A2E12),
      ink: Color(0xFFF7DFA8),
      accent: ZbTokens.amberOnDark,
      onAccent: Color(0xFF3A2E12),
    ),
    _OfferPalette(
      ground: ZbTokens.coralContainerDark,
      ink: Color(0xFFF6BCB0),
      accent: ZbTokens.coralOnDark,
      onAccent: Color(0xFF4A241D),
    ),
  ];

  static _OfferPalette of(BuildContext context, HeroSlide slide, int index) {
    final List<_OfferPalette> set = context.isDark ? _dark : _light;
    final int slot = switch (slide.theme) {
      'express' || 'express_clock' || 'express_hours' || 'cutoff' => 0,
      'bestsellers' || 'express_top' || 'brand' => 1,
      'newin' || 'express_new' || 'bundles' => 2,
      'clearance' => 3,
      // An unknown theme still has to differ from its neighbour.
      _ => index % 4,
    };
    return set[slot];
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.slide, required this.palette});

  final HeroSlide slide;
  final _OfferPalette palette;

  void _follow(BuildContext context) {
    Haptics.light();
    final String? route = autoSlideRoute(slide);
    if (route != null) {
      context.push(route);
      return;
    }
    // A manual banner carries a plain URL and nothing else to go on.
    final String? url = slide.linkUrl;
    if (url != null && url.isNotEmpty) {
      followLink(context, ZbLink.fromUrl(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? art = slide.productImages.isNotEmpty
        ? slide.productImages.first
        : slide.bestImage;
    final double height = ExpressOfferSlider.cardHeight(context);
    final double artBox = math.max(72, height - 30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _follow(context),
        child: Ink(
          // The disc runs past the card, so the corners have to hold it in.
          decoration: BoxDecoration(
            color: palette.ground,
            borderRadius: BorderRadius.circular(24),
            // A hairline of the card's own accent, not grey: on a pale ground
            // a neutral border reads as a seam, a tinted one as an edge.
            border: Border.all(color: palette.accent.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // A breath of the card's own accent behind the trailing
                // edge. It gives the ground somewhere to go — a pale
                // rectangle with type on it is a note, not a card — and it
                // sits where the product does, so the eye finds weight where
                // it expects it.
                //
                // A gradient, not a disc: a solid circle even at 7% still
                // draws a visible arc across the card, which reads as a shape
                // rather than as light.
                PositionedDirectional(
                  end: -height * 0.42,
                  top: -height * 0.34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.accent.withValues(alpha: 0.13),
                          palette.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: SizedBox(
                      width: height * 1.5,
                      height: height * 1.5,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 8,
                          top: 14,
                          bottom: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if ((slide.badge ?? '').isNotEmpty) ...[
                              _Kicker(text: slide.badge!, palette: palette),
                              const SizedBox(height: 7),
                            ],
                            if ((slide.title ?? '').isNotEmpty)
                              Text(
                                slide.title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.titleMedium?.copyWith(
                                  color: palette.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.22,
                                ),
                              ),
                            if ((slide.subtitle ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                slide.subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.bodySmall?.copyWith(
                                  color: palette.ink.withValues(alpha: 0.72),
                                  height: 1.3,
                                ),
                              ),
                            ],
                            if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _Cta(label: slide.ctaLabel!, palette: palette),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (art != null && art.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: SizedBox(
                          width: artBox * 0.86,
                          height: artBox,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // A breath of the accent behind the cut-out, so the
                              // product sits ON the card rather than beside it.
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      palette.accent.withValues(alpha: 0.20),
                                      palette.accent.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                                child: SizedBox(width: artBox, height: artBox),
                              ),
                              ZbImage(url: art, fit: BoxFit.contain),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.text, required this.palette});

  final String text;
  final _OfferPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: palette.accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.tt.labelSmall?.copyWith(
        color: palette.accent,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.palette});

  final String label;
  final _OfferPalette palette;

  @override
  Widget build(BuildContext context) {
    // Solid, not a ghost: on a pale ground the one thing that should look
    // pressable has to be the one thing carrying weight.
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 8,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(
              color: palette.onAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          Icon(
            context.isRtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 16,
            color: palette.onAccent.withValues(alpha: 0.92),
          ),
        ],
      ),
    );
  }
}

/// Where you are in the strip. The active dot stretches into a pill rather
/// than merely brightening — a shape change is legible at three millimetres,
/// a tint change is not.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.still});

  final int count;
  final int index;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final Color on = context.cs.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 260),
            curve: Motion.emphasized,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: on.withValues(alpha: i == index ? 0.72 : 0.20),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
