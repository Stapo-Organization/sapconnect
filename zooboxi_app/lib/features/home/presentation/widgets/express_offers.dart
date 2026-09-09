import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
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
///
/// The dark store cannot afford the same screen. What it can afford is a strip
/// of cards the width of a thumb's swipe, with the next one already peeking —
/// the shape every delivery app uses for its promos, precisely because it says
/// "there is more here" without taking the page. Same slides the server
/// composes for the hero, drawn small and in the ember.
class ExpressOfferSlider extends StatefulWidget {
  const ExpressOfferSlider({super.key, required this.slides});

  final List<HeroSlide> slides;

  /// A strip with nothing to put in it renders nothing at all.
  static bool hasContent(List<HeroSlide> slides) => slides.any(
        (s) => (s.title ?? '').isNotEmpty || (s.bestImage ?? '').isNotEmpty,
      );

  /// Short — this is a strip in the feed, not the first screen.
  static const double cardHeight = 128;

  /// The next card peeks, which is the whole invitation to swipe.
  static const double _viewport = 0.86;

  @override
  State<ExpressOfferSlider> createState() => _ExpressOfferSliderState();
}

class _ExpressOfferSliderState extends State<ExpressOfferSlider> {
  late final PageController _pages = PageController(
    viewportFraction: ExpressOfferSlider._viewport,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (!ExpressOfferSlider.hasContent(slides)) return const SizedBox.shrink();

    return SizedBox(
      height: ExpressOfferSlider.cardHeight,
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: slides.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
          child: _OfferCard(slide: slides[index], index: index),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.slide, required this.index});

  final HeroSlide slide;

  /// Only to vary the ground: three identical cards in a row read as one
  /// mistake repeated.
  final int index;

  /// Ember, walked a few degrees per card so a swipe feels like movement
  /// rather than a redraw. Still one family — this is إكسبريس throughout.
  static const List<List<Color>> _grounds = [
    [Color(0xFFB94510), Color(0xFFDB6A22)],
    [Color(0xFF9C3D18), Color(0xFFC85A17)],
    [Color(0xFFC2410C), Color(0xFFE8873A)],
  ];

  void _follow(BuildContext context) {
    Haptics.light();
    final String? route = autoSlideRoute(slide);
    if (route != null) {
      context.push(route);
      return;
    }
    // A manual banner carries a plain URL and nothing else to go on.
    unawaitedFollow(context, slide.linkUrl);
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> ground = _grounds[index % _grounds.length];
    final String? art = slide.productImages.isNotEmpty
        ? slide.productImages.first
        : slide.bestImage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        onTap: () => _follow(context),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: ground,
            ),
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            boxShadow: [
              BoxShadow(
                color: ground.last.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 14,
                    end: 8,
                    top: 12,
                    bottom: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((slide.title ?? '').isNotEmpty)
                        Text(
                          slide.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      if ((slide.subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          slide.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.25,
                          ),
                        ),
                      ],
                      if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            slide.ctaLabel!,
                            style: context.tt.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (art != null && art.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: SizedBox(
                    width: ExpressOfferSlider.cardHeight - 18,
                    height: ExpressOfferSlider.cardHeight - 18,
                    child: ZbImage(url: art, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The link helper is async and nothing here awaits it — a tap that opens a
/// tab has no result this card can use.
void unawaitedFollow(BuildContext context, String? url) {
  if (url == null || url.isEmpty) return;
  followLink(context, ZbLink.fromUrl(url));
}
