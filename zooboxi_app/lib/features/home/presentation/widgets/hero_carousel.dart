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
import 'home_header.dart';
import 'link_navigation.dart';

/// Placement zones whose creatives belong in the hero rather than in a banner
/// slot. Shared with the home screen so a campaign can never be counted twice.
const List<String> heroZones = ['hero', 'app_hero'];

/// The campaigns the carousel will actually show, in the order it shows them.
List<Campaign> heroCampaignsOf(List<Campaign> campaigns) =>
    campaigns.where((c) => c.inAnyZone(heroZones)).toList();

/// Hero geometry. The slide area is a fixed-extent element, so — exactly like
/// a product card — its height is *computed* from the text scale rather than
/// guessed and hoped for. The scale is clamped at 1.3× in both the arithmetic
/// and the painted copy, so the number here and the pixels can't disagree.
abstract final class HeroMetrics {
  /// Slides are full-bleed: the canvas owns the whole width, like the header
  /// it fuses with.
  static const double aspect = 1.9;
  static const double maxTextScale = 1.3;

  /// How much taller the slide area gets at the top of the text-scale range.
  static const double scaleHeadroom = 96;

  /// The strip under the slide copy that the page dots live in.
  static const double dotsBand = 26;

  static double height(BuildContext context, double width) {
    final factor =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxTextScale).scale(16) / 16;
    return width / aspect + (factor - 1) * scaleHeadroom;
  }
}

/// The storefront's marquee: **one colored canvas** that starts behind the
/// status bar, carries the location row and the search field, and ends as the
/// hero slide — the pattern the big delivery apps use. Every slide brings its
/// own canvas color, and because the canvas is painted *inside* the page, the
/// color boundary drags with the customer's finger mid-swipe instead of
/// snapping when the page settles.
///
/// The header itself does not pan: it floats fixed above the pages, and each
/// page reserves its exact height with an invisible twin — so the two can
/// never drift apart, at any text size.
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
  late final PageController _controller = PageController();
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
    final statusTop = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final fallback = _canvasFallback(context);

    if (items.isEmpty) {
      // Data can only shrink to zero on a refresh gone strange — keep the
      // header usable on its own canvas rather than vanishing the whole unit.
      return _CanvasShell(
        statusTop: statusTop,
        decoration: BoxDecoration(gradient: fallback),
        child: const SizedBox.shrink(),
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: HeroMetrics.maxTextScale,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            // The panning layer: canvas color + slide content per page. It
            // fills whatever height the fixed foreground column decides.
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                itemCount: items.length,
                onPageChanged: (index) {
                  setState(() => _index = index);
                  _reportImpression(index);
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  return DecoratedBox(
                    decoration: BoxDecoration(gradient: item.canvas(context)),
                    child: Column(
                      children: [
                        SizedBox(height: statusTop),
                        // The invisible twin that reserves the header's exact
                        // height inside the page — measurement by construction.
                        const _HeaderGhost(),
                        Expanded(
                          child: PressScale(
                            onTap: () => _open(item),
                            child: switch (item) {
                              _ManualItem(:final slide) => _ManualSlide(slide: slide),
                              _CampaignItem(:final campaign) =>
                                _CampaignSlide(campaign: campaign),
                              _AutoItem(:final slide) => HeroAutoCard(slide: slide, flush: true),
                            },
                          ),
                        ),
                        const SizedBox(height: HeroMetrics.dotsBand),
                      ],
                    ),
                  );
                },
              ),
            ),

            // The fixed foreground: status inset + the real header + the space
            // the slides show through. Empty boxes are hit-test transparent,
            // so swipes and slide taps fall straight through to the pages.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: statusTop),
                const HomeHeader(onCanvas: true),
                SizedBox(height: HeroMetrics.height(context, width)),
                const SizedBox(height: HeroMetrics.dotsBand),
              ],
            ),

            if (items.length > 1)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 9,
                child: _Dots(count: items.length, index: _index),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _canvasFallback(BuildContext context) => context.isDark
      ? const LinearGradient(colors: [ZbTokens.tealContainerDark, ZbTokens.graphiteHigh])
      : const LinearGradient(colors: [ZbTokens.tealDeep, ZbTokens.tealDark]);
}

/// The degenerate no-slides shell: canvas + header only.
class _CanvasShell extends StatelessWidget {
  const _CanvasShell({
    required this.statusTop,
    required this.decoration,
    required this.child,
  });

  final double statusTop;
  final BoxDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: statusTop),
            const HomeHeader(onCanvas: true),
            child,
            Gap.h8,
          ],
        ),
      ),
    );
  }
}

/// The header's invisible twin: same widget, same width, zero paint, zero
/// pointer — its only job is to make every page reserve exactly the height the
/// real header occupies above it.
class _HeaderGhost extends StatelessWidget {
  const _HeaderGhost();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(opacity: 0, child: HomeHeader(onCanvas: true)),
      ),
    );
  }
}

// ── Items ──────────────────────────────────────────────────────────────

sealed class _HeroItem {
  const _HeroItem();

  ZbLink? get link;
  String? get title;

  /// The canvas this slide paints the whole unit with — status bar to dots.
  LinearGradient canvas(BuildContext context);
}

class _ManualItem extends _HeroItem {
  const _ManualItem(this.slide);

  final HeroSlide slide;

  @override
  ZbLink? get link => ZbLink.fromUrl(slide.linkUrl);

  @override
  String? get title => slide.title;

  @override
  LinearGradient canvas(BuildContext context) => context.isDark
      ? const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [ZbTokens.tealContainerDark, ZbTokens.graphiteHigh],
        )
      : const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [ZbTokens.tealDeep, ZbTokens.tealDark],
        );
}

class _AutoItem extends _HeroItem {
  const _AutoItem(this.slide);

  final HeroSlide slide;

  @override
  ZbLink? get link => ZbLink.fromUrl(slide.linkUrl);

  @override
  String? get title => slide.title;

  @override
  LinearGradient canvas(BuildContext context) =>
      AutoSlideSkin.of(context, slide.theme).gradient;
}

class _CampaignItem extends _HeroItem {
  const _CampaignItem(this.campaign);

  final Campaign campaign;

  @override
  ZbLink? get link => ZbLink.fromUrl(campaign.linkUrl, productId: campaign.productId);

  @override
  String? get title => campaign.headline;

  @override
  LinearGradient canvas(BuildContext context) =>
      CampaignPanel.of(context, campaignType: campaign.campaignType).gradient;
}

// ── Slides ─────────────────────────────────────────────────────────────

/// An uploaded banner: the artwork fills the slide area of the canvas, a scrim
/// only where the copy sits so the art stays bright.
class _ManualSlide extends StatelessWidget {
  const _ManualSlide({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final hasCopy = (slide.title ?? '').isNotEmpty || (slide.subtitle ?? '').isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        ZbImage(url: slide.bestImage, fit: BoxFit.cover, backgroundColor: Colors.transparent),
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
            bottom: 12,
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

/// A live campaign, composed natively on the slide's own canvas — see
/// [CampaignComposition] for why the artwork is never trusted to carry the
/// words.
class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final panel = CampaignPanel.of(context, campaignType: campaign.campaignType);
    final headline = campaign.headline;
    final subheadline = campaign.subheadline;
    final cta = campaign.cta;

    return CampaignComposition(
      panel: panel,
      // The page already painted the panel gradient from the status bar down.
      paintBackground: false,
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
    // The dots always sit on a deep canvas, so they are always light.
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
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
          ),
        );
      }),
    );
  }
}
