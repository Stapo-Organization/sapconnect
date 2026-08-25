import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'link_navigation.dart';

/// The hero banner strip. Slides and campaign placements share the carousel —
/// to a customer they are the same thing, and merging them means an active
/// campaign is never buried below a static banner.
class HeroCarousel extends ConsumerStatefulWidget {
  const HeroCarousel({super.key, required this.slides, this.campaigns = const []});

  final List<HeroSlide> slides;
  final List<Campaign> campaigns;

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  late final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _autoplay;
  int _index = 0;

  List<_Slide> get _items => [
        for (final slide in widget.slides)
          _Slide(
            image: slide.bestImage,
            title: slide.title,
            subtitle: slide.subtitle,
            cta: slide.ctaLabel,
            link: ZbLink.fromUrl(slide.linkUrl),
          ),
        for (final campaign in widget.campaigns)
          if (campaign.inZone('hero'))
            _Slide(
              image: campaign.image,
              title: campaign.headline,
              link: ZbLink.fromUrl(campaign.linkUrl, productId: campaign.productId),
              campaignId: campaign.campaignId,
              abVariant: campaign.abVariant,
              zone: 'hero',
            ),
      ];

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    if (_items.length < 2) return;
    _autoplay = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      // Reduce Motion means "don't move things on your own": no autoplay.
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_index + 1) % _items.length;
      _controller.animateToPage(next, duration: Motion.page, curve: Motion.emphasized);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.92) * 0.52;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final slide = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _HeroCard(
                  slide: slide,
                  onTap: () {
                    if (slide.campaignId != null) {
                      ref.track(ZbEvent(
                        type: ZbEvents.campaignClick,
                        campaignId: slide.campaignId,
                        abVariant: slide.abVariant,
                        zone: slide.zone,
                      ));
                    }
                    followLink(context, slide.link, title: slide.title);
                  },
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          Gap.h12,
          _Dots(count: items.length, index: _index),
        ],
      ],
    );
  }
}

class _Slide {
  const _Slide({
    this.image,
    this.title,
    this.subtitle,
    this.cta,
    this.link,
    this.campaignId,
    this.abVariant,
    this.zone,
  });

  final String? image;
  final String? title;
  final String? subtitle;
  final String? cta;
  final ZbLink? link;
  final String? campaignId;
  final String? abVariant;
  final String? zone;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.slide, required this.onTap});

  final _Slide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hasCopy = (slide.title ?? '').isNotEmpty || (slide.subtitle ?? '').isNotEmpty;

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ZbImage(url: slide.image, fit: BoxFit.cover),
            if (hasCopy)
              // A scrim only where the text sits, so the artwork stays bright.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            if (hasCopy)
              PositionedDirectional(
                start: 18,
                end: 90,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((slide.title ?? '').isNotEmpty)
                      Text(
                        slide.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if ((slide.subtitle ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          slide.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    if ((slide.cta ?? '').isNotEmpty) ...[
                      Gap.h12,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          slide.cta!,
                          style: context.tt.labelMedium?.copyWith(color: cs.onSurface),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: Motion.select,
          curve: Motion.decelerate,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
