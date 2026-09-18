import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';
import 'campaign_composition.dart';
import 'campaign_impression.dart';
import 'hero_light_card.dart';
import 'hero_live_copy.dart';
import 'home_header.dart';
import 'link_navigation.dart';

/// Placement zones whose creatives belong in the hero rather than in a banner
/// slot. Shared with the home screen so a campaign can never be counted twice.
const List<String> heroZones = ['hero', 'app_hero'];

/// The campaigns the carousel will actually show, in the order it shows them.
List<Campaign> heroCampaignsOf(List<Campaign> campaigns) =>
    campaigns.where((c) => c.inAnyZone(heroZones)).toList();

/// Where a **server-composed** slide goes, as an in-app location.
///
/// Auto slides are merchandising the server assembled out of live catalogue
/// data — express stock, clearance, a brand, the bestsellers — and the store
/// URL it attaches is a web address for the same idea. Following that URL threw
/// the customer into a browser tab mid-shop (and the clearance slide shipped no
/// link at all, so it did nothing). Every theme therefore resolves to a screen
/// this app already owns, and the ranking behind each one is the same ranking
/// the slide was built from.
///
/// Returns null only for a theme this build has never heard of — the slide then
/// stays inert rather than guessing, which is the same contract the home layout
/// uses for unknown slots.
String? autoSlideRoute(HeroSlide slide) {
  final title = slide.title ?? '';

  String listing([Map<String, String> scope = const {}]) {
    final query = {...scope, if (title.isNotEmpty) 'title': title};
    return query.isEmpty
        ? '/listing'
        : Uri(path: '/listing', queryParameters: query).toString();
  }

  return switch (slide.theme) {
    'clearance' => listing(const {'rail': 'clearance'}),
    'bestsellers' || 'express_top' => listing(const {'rail': 'bestsellers'}),
    'newin' || 'express_new' => listing(const {'rail': 'new'}),
    'bundles' => '/bundles',
    // No rail key: the listing's own recommended sort already floats what is
    // in a nearby warehouse to the top, which *is* the express promise.
    'express' || 'express_clock' || 'express_hours' || 'cutoff' => listing(),
    'brand' => switch (ZbLink.fromUrl(slide.linkUrl)) {
      ZbLink(type: 'brand', :final value) => brandLocation(value, title: title),
      // A brand slide whose link the server didn't spell as a brand archive
      // still has a headline worth honouring.
      _ => listing(),
    },
    _ => null,
  };
}

/// Hero geometry.
///
/// «الحيّ الأبيض» (2026-09-18): the slide is a card of fixed height on a
/// light canvas, not a band cut from the screen width. The card's height is
/// computed from the text scale — like a product card — so the number here
/// and the pixels can't disagree. [aspect] and the band arithmetic are kept
/// for the express offer strip and its golden, which still draw the old
/// deep-field slides small.
abstract final class HeroMetrics {
  static const double aspect = 3.2;
  static const double maxTextScale = 1.3;
  static const double scaleHeadroom = 200;

  /// The old strip under the slides. The dots now sit in the product's spill
  /// zone, so the unit reserves nothing below the card but that.
  static const double dotsBand = 0;

  static double _factor(BuildContext context) =>
      MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: maxTextScale).scale(16) /
      16;

  /// The card proper.
  static double height(BuildContext context, double width) =>
      LightCardMetrics.height +
      (_factor(context) - 1) * LightCardMetrics.scaleHeadroom;

  /// The card plus the room its product hangs into — what one page reserves.
  static double page(BuildContext context, double width) =>
      height(context, width) + LightCardMetrics.spill;
}

/// The storefront's marquee, on a light canvas that starts behind the status
/// bar and carries the shelf tabs, the address row and the search button —
/// and under them the slide, as a pastel card with its product spilling over
/// the bottom edge into the page.
///
/// The canvas is one colour, so the header no longer needs a panning twin:
/// it sits above the pages, and the pages carry only the cards.
class HeroCarousel extends ConsumerStatefulWidget {
  const HeroCarousel({
    super.key,
    required this.slides,
    this.campaigns = const [],
    this.scope,
  });

  final List<HeroSlide> slides;
  final List<Campaign> campaigns;

  /// The active shelf's sentence, threaded down to the header's ribbon.
  final CatalogScope? scope;

  /// Whether there is anything at all to show — campaigns count, which is the
  /// point: a campaign-only hero used to be hidden by an `hero.isEmpty` gate.
  static bool hasContent(HomePayload payload) =>
      payload.hero.isNotEmpty || heroCampaignsOf(payload.campaigns).isNotEmpty;

  /// The canvas behind the whole unit — cream by day, the raised graphite by
  /// night. Exposed so the status bar can pick a clock colour to match.
  static Color canvasColor(BuildContext context) =>
      context.isDark ? ZbTokens.graphiteRaised : ZbTokens.cream;

  @override
  ConsumerState<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<HeroCarousel>
    with WidgetsBindingObserver {
  late final PageController _controller = PageController();
  Timer? _autoplay;
  int _index = 0;

  /// Whether the hero is actually on screen. Scrolled past the fold — or on the
  /// storefront the customer just left — it keeps animating a page nobody can
  /// see, and every sixth second costs a page transition, a rebuild and a
  /// repaint while they are reading something else further down.
  bool _visible = true;

  /// Whether the app is in front of the customer at all.
  bool _foreground = true;

  /// Item count the running autoplay timer was built for.
  int _autoplayCount = 0;

  /// Manual banners first (they are bought and paid for), then live campaigns,
  /// then the slides the server composed to fill the gap.
  List<_HeroItem> get _items => [
    for (final slide in widget.slides)
      if (!slide.isAuto) _ManualItem(slide),
    for (final campaign in heroCampaignsOf(widget.campaigns))
      _CampaignItem(campaign),
    // A composed slide is only true for a while: the payload is held for
    // the life of this screen and read again off disk at launch, so the
    // ones whose moment has passed leave rather than repeat themselves
    // until the refresh lands.
    for (final slide in widget.slides)
      if (slide.isAuto && !heroSlideIsStale(slide, widget.scope))
        _AutoItem(slide),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoplay();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportImpression(0));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _startAutoplay();
  }

  /// Called by the visibility detector wrapped around the carousel.
  void _onVisibility(double fraction) {
    // Half on screen is the same threshold the campaign impression uses, so a
    // slide that counts as "shown" is exactly a slide that is allowed to move.
    final visible = fraction >= 0.5;
    if (visible == _visible) return;
    _visible = visible;
    _startAutoplay();
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reportImpression(_index),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplay?.cancel();
    _autoplay = null;
    _autoplayCount = _items.length;
    if (_autoplayCount < 2) return;
    // Nothing turns by itself while nobody is looking.
    if (!_visible || !_foreground) return;

    _autoplay = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      // Reduce Motion means "don't move things on your own": no autoplay.
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_index + 1) % _items.length;
      unawaited(
        _controller.animateToPage(
          next,
          duration: Motion.page,
          curve: Motion.emphasized,
        ),
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
    // A slide the *server composed out of our own catalogue* must never hand
    // the customer to a browser: it resolves to an app screen or it does
    // nothing. `followLink` is deliberately out of reach here — it can open a
    // custom tab, and that is the exact outcome this closes off.
    if (item is _AutoItem) {
      final route = autoSlideRoute(item.slide);
      if (route != null) unawaited(context.push(route));
      return;
    }
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
    final canvas = HeroCarousel.canvasColor(context);

    if (items.isEmpty) {
      // Data can only shrink to zero on a refresh gone strange — keep the
      // header usable on its own canvas rather than vanishing the whole unit.
      return _CanvasShell(statusTop: statusTop, color: canvas, scope: widget.scope);
    }

    return VisibilityDetector(
      // Keyed to this element, so the two storefronts alive during the 380ms
      // crossing cannot collide on one key and report each other's fraction.
      key: ValueKey('hero-${identityHashCode(this)}'),
      onVisibilityChanged: (info) => _onVisibility(info.visibleFraction),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: HeroMetrics.maxTextScale,
        child: DecoratedBox(
          decoration: BoxDecoration(color: canvas),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: statusTop),
              // The ordinary header — ink on a light ground — is exactly what a
              // light canvas wants; the deep-canvas variant is for the express
              // promise header alone now.
              HomeHeader(scope: widget.scope),
              SizedBox(
                height: HeroMetrics.page(context, width),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: items.length,
                        onPageChanged: (index) {
                          setState(() => _index = index);
                          _reportImpression(index);
                        },
                        itemBuilder: (context, index) => _Page(
                          item: items[index],
                          scope: widget.scope,
                          cardHeight: HeroMetrics.height(context, width),
                          onTap: () => _open(items[index]),
                        ),
                      ),
                    ),
                    // Under the card, in the spill zone, aligned with the copy
                    // column: the product hangs on the other side, and the
                    // card's top corner belongs to whatever sticker the art
                    // brought («+3 مجانًا» sits exactly there).
                    if (items.length > 1)
                      PositionedDirectional(
                        start: LightCardMetrics.margin + 20,
                        top: HeroMetrics.height(context, width) + 9,
                        child: IgnorePointer(
                          child: _Dots(count: items.length, index: _index),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page: the card, with room under it for the product to hang into.
class _Page extends StatelessWidget {
  const _Page({
    required this.item,
    required this.scope,
    required this.cardHeight,
    required this.onTap,
  });

  final _HeroItem item;
  final CatalogScope? scope;
  final double cardHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: LightCardMetrics.margin,
        end: LightCardMetrics.margin,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: cardHeight,
          width: double.infinity,
          child: PressScale(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LightCardMetrics.radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3C2814).withValues(
                      alpha: context.isDark ? 0.35 : 0.10,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: switch (item) {
                _AutoItem(:final slide) => LightSlideCard(slide: slide, scope: scope),
                _CampaignItem(:final campaign) => _CampaignSlide(campaign: campaign),
                _ManualItem(:final slide) => _ManualSlide(slide: slide),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The degenerate no-slides shell: canvas + header only.
class _CanvasShell extends StatelessWidget {
  const _CanvasShell({
    required this.statusTop,
    required this.color,
    required this.scope,
  });

  final double statusTop;
  final Color color;
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: statusTop),
          HomeHeader(scope: scope),
          Gap.h8,
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
  ZbLink? get link =>
      ZbLink.fromUrl(campaign.linkUrl, productId: campaign.productId);

  @override
  String? get title => campaign.headline;
}

// ── Slides ─────────────────────────────────────────────────────────────

/// An uploaded banner: the artwork fills the card, a scrim only where the copy
/// sits so the art stays bright.
class _ManualSlide extends StatelessWidget {
  const _ManualSlide({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final hasCopy =
        (slide.title ?? '').isNotEmpty || (slide.subtitle ?? '').isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(LightCardMetrics.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ZbImage(
            url: slide.bestImage,
            fit: BoxFit.cover,
            backgroundColor: Colors.transparent,
            decodeWidth: ZbDecode.hero,
          ),
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
              bottom: 14,
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
      ),
    );
  }
}

/// A live campaign, composed natively inside the card on its own panel — see
/// [CampaignComposition] for why the artwork is never trusted to carry the
/// words.
class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final panel = CampaignPanel.of(
      context,
      campaignType: campaign.campaignType,
    );
    final headline = campaign.headline;
    final subheadline = campaign.subheadline;
    final cta = campaign.cta;

    return ClipRRect(
      borderRadius: BorderRadius.circular(LightCardMetrics.radius),
      child: CampaignComposition(
        panel: panel,
        padding: const EdgeInsetsDirectional.only(
          start: 18,
          end: 12,
          top: 10,
          bottom: 10,
        ),
        art: campaign.artFor(const ['app_hero', 'card', 'hero', 'wide']),
        copy: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
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
            if ((cta ?? '').isNotEmpty) ...[Gap.h12, CampaignCta(label: cta!)],
            Gap.h8,
            CampaignChipRow(
              campaign: campaign,
              panel: panel,
              includeBadge: false,
              maxChips: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// The page dots, as a small pill just under the card — teal for the page you
/// are on. It sits over the pages rather than in them, so it holds still while
/// the cards move under it.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: (dark ? Colors.white : ZbTokens.ink).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: Motion.select,
            curve: Motion.decelerate,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: active ? 16 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: active
                  ? ZbTokens.teal
                  : context.cs.onSurface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(ZbTokens.rPill),
            ),
          );
        }),
      ),
    );
  }
}
