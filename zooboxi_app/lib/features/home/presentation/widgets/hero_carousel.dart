import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';
import 'campaign_composition.dart';
import 'campaign_impression.dart';
import 'hero_auto_slide.dart';
import 'link_navigation.dart';

/// Placement zones whose creatives belong in the hero rather than in a banner
/// slot. Shared with the home screen so a campaign can never be counted twice.
const List<String> heroZones = ['hero', 'app_hero'];

/// The campaigns the carousel will actually show, in the order it shows them.
List<Campaign> heroCampaignsOf(List<Campaign> campaigns) =>
    campaigns.where((c) => c.inAnyZone(heroZones)).toList();

/// Hero geometry. The card is a fixed-extent element, so — exactly like a
/// product card — its height is *computed* from the text scale rather than
/// guessed and hoped for. The scale is clamped at 1.3× in both the arithmetic
/// and the painted copy, so the number here and the pixels can't disagree.
abstract final class HeroMetrics {
  static const double viewportFraction = 0.92;
  static const double aspect = 1.6;
  static const double maxTextScale = 1.3;

  /// How much taller the card gets at the top of the text-scale range.
  static const double scaleHeadroom = 96;

  static double height(BuildContext context, double width) {
    final factor =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxTextScale).scale(16) / 16;
    return (width * viewportFraction) / aspect + (factor - 1) * scaleHeadroom;
  }
}

/// The hero strip. Uploaded banners, live campaign placements and the slides
/// the server composes from stock all share one carousel — to a customer they
/// are the same thing, and merging them means an active campaign is never
/// buried below a static banner.
class HeroCarousel extends ConsumerStatefulWidget {
  const HeroCarousel({super.key, required this.slides, this.campaigns = const []});

  final List<HeroSlide> slides;
  final List<Campaign> campaigns;

  /// Whether there is anything at all to show — campaigns count, which is the
  /// point: a campaign-only hero used to be hidden by an `hero.isEmpty` gate.
  static bool hasContent(HomePayload payload) =>
      payload.hero.isNotEmpty || heroCampaignsOf(payload.campaigns).isNotEmpty;

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: HeroMetrics.viewportFraction);
  Timer? _autoplay;
  int _index = 0;

  /// Item count the running autoplay timer was built for.
  int _autoplayCount = 0;

  /// Manual banners first (they are bought and paid for), then live campaigns,
  /// then the slides the server composed to fill the gap.
  List<_HeroItem> get _items => [
        for (final slide in widget.slides)
          if (!slide.isAuto) _ManualItem(slide),
        for (final campaign in heroCampaignsOf(widget.campaigns)) _CampaignItem(campaign),
        for (final slide in widget.slides)
          if (slide.isAuto) _AutoItem(slide),
      ];

  @override
  void initState() {
    super.initState();
    _startAutoplay();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportImpression(0));
  }

  @override
  void didUpdateWidget(HeroCarousel old) {
    super.didUpdateWidget(old);
    // The slide list arrives, then grows when the network refresh lands. An
    // autoplay timer started against the old count either never starts or
    // cycles a page that no longer exists — restart it whenever the count moves.
    final count = _items.length;
    if (count != _autoplayCount) {
      if (_index >= count) _index = count == 0 ? 0 : count - 1;
      _startAutoplay();
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportImpression(_index));
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    _autoplay = null;
    _autoplayCount = _items.length;
    if (_autoplayCount < 2) return;

    _autoplay = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      // Reduce Motion means "don't move things on your own": no autoplay.
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_index + 1) % _items.length;
      unawaited(
        _controller.animateToPage(next, duration: Motion.page, curve: Motion.emphasized),
      );
    });
  }

  /// The hero has no scroll position of its own to measure, so "shown" is
  /// "became the current page" — which is the same thing to a customer.
  void _reportImpression(int index) {
    if (!mounted) return;
    final items = _items;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (item is _CampaignItem) {
      trackCampaignImpression(ref, item.campaign, 'hero');
    }
  }

  void _open(_HeroItem item) {
    if (item is _CampaignItem) {
      trackCampaignClick(ref, item.campaign, 'hero');
    }
    unawaited(followLink(context, item.link, title: item.title));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: HeroMetrics.maxTextScale,
      child: Column(
        children: [
          SizedBox(
            height: HeroMetrics.height(context, width),
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _reportImpression(index);
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: PressScale(
                    onTap: () => _open(item),
                    borderRadius: BorderRadius.circular(ZbTokens.rLg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ZbTokens.rLg),
                      child: switch (item) {
                        _ManualItem(:final slide) => _ManualCard(slide: slide),
                        _CampaignItem(:final campaign) => _CampaignCard(campaign: campaign),
                        _AutoItem(:final slide) => HeroAutoCard(slide: slide),
                      },
                    ),
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
      ),
    );
  }
}

// ── Items ──────────────────────────────────────────────────────────────

sealed class _HeroItem {
  const _HeroItem();

  ZbLink? get link;
  String? get title;
}

class _ManualItem extends _HeroItem {
  const _ManualItem(this.slide);

  final HeroSlide slide;

  @override
  ZbLink? get link => ZbLink.fromUrl(slide.linkUrl);

  @override
  String? get title => slide.title;
}

class _AutoItem extends _HeroItem {
  const _AutoItem(this.slide);

  final HeroSlide slide;

  @override
  ZbLink? get link => ZbLink.fromUrl(slide.linkUrl);

  @override
  String? get title => slide.title;
}

class _CampaignItem extends _HeroItem {
  const _CampaignItem(this.campaign);

  final Campaign campaign;

  @override
  ZbLink? get link => ZbLink.fromUrl(campaign.linkUrl, productId: campaign.productId);

  @override
  String? get title => campaign.headline;
}

// ── Cards ──────────────────────────────────────────────────────────────

/// An uploaded banner: full-bleed art, a scrim only where the copy sits so the
/// artwork stays bright.
class _ManualCard extends StatelessWidget {
  const _ManualCard({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final hasCopy = (slide.title ?? '').isNotEmpty || (slide.subtitle ?? '').isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        ZbImage(url: slide.bestImage, fit: BoxFit.cover),
        if (hasCopy)
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
                if ((slide.ctaLabel ?? '').isNotEmpty) ...[
                  Gap.h12,
                  CampaignCta(label: slide.ctaLabel!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A live campaign, composed natively — see [CampaignComposition] for why the
/// artwork is never trusted to carry the words.
class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final panel = CampaignPanel.of(context, campaignType: campaign.campaignType);
    final headline = campaign.headline;
    final subheadline = campaign.subheadline;
    final cta = campaign.cta;

    return CampaignComposition(
      panel: panel,
      art: campaign.artFor(const ['app_hero', 'card', 'hero', 'wide']),
      copy: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((campaign.badge ?? '').isNotEmpty) ...[
            CampaignBadgeChip(campaign: campaign, panel: panel),
            Gap.h8,
          ],
          if ((headline ?? '').isNotEmpty)
            Flexible(
              child: Text(
                headline!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleLarge?.copyWith(
                  color: panel.fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if ((subheadline ?? '').isNotEmpty) ...[
            Gap.h4,
            Flexible(
              child: Text(
                subheadline!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(color: panel.muted),
              ),
            ),
          ],
          if ((cta ?? '').isNotEmpty) ...[
            Gap.h12,
            CampaignCta(label: cta!),
          ],
          Gap.h8,
          CampaignChipRow(
            campaign: campaign,
            panel: panel,
            includeBadge: false,
            maxChips: 2,
          ),
        ],
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
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
          ),
        );
      }),
    );
  }
}
