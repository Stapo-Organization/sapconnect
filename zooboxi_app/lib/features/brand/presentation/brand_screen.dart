import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paginated_grid.dart';
import '../../../core/widgets/rail.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/presentation/widgets/facet_sheet.dart';
import '../../catalog/presentation/widgets/sort_sheet.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/brand_identity.dart';
import 'widgets/brand_sections.dart';

/// A brand's boutique page.
///
/// It exists because a brand is how a lot of pet owners actually shop — they
/// bought Applaws once and they are looking for Applaws again — and because
/// sending that customer to a filtered listing throws away everything the brand
/// is. The page is one scroll view: stage, identity, departments, the brand's
/// own picks, then its whole catalogue paging underneath. The grid owns that
/// scroll (see [PaginatedProductGrid.leadingSlivers]), so there is exactly one
/// thing on screen to fling.
///
/// Every rich element is conditional. Most brands have no hero art, no tagline
/// and no story yet, and the page has to look *finished* in that state, not
/// like a template with the content missing.
class BrandScreen extends ConsumerStatefulWidget {
  const BrandScreen({super.key, required this.slug, this.name = ''});

  final String slug;

  /// The name the caller already knew, so the app bar can be honest during the
  /// first load instead of showing a slug.
  final String name;

  @override
  ConsumerState<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends ConsumerState<BrandScreen> {
  /// How tall the stage stands before it collapses into the app bar.
  static const double _stage = 188;

  /// The grid's whole scope: brand always, plus the chosen department, the
  /// facet selections and the sort — one object, one reset key.
  late ListingQuery _query = ListingQuery(brand: widget.slug);

  /// Facets, price bounds and sort options describe the *current* result set —
  /// captured from whichever page-1 response came back last, as a listing does.
  List<FacetGroup> _facets = const [];
  PriceFacet? _priceBounds;
  List<SortOption> _sortOptions = const [];

  /// True once the stage has scrolled away and the bar is a plain app bar.
  bool _collapsed = false;

  /// How many products the current scope holds — captured from whichever
  /// page-1 response came back last, exactly as a listing does it.
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.track(ZbEvent(
        type: ZbEvents.view,
        zone: 'brand',
        payload: {'brand': widget.slug},
      ));
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final collapsed = notification.metrics.pixels > _stage - kToolbarHeight - 8;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  Future<ListingResult> _fetch(int page) async {
    final result = await ref.read(catalogRepositoryProvider).products(_query, page);
    _seedHearts(result.products);
    if (page == 1) {
      // Deferred: this runs inside the grid's own build/fetch cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _total = result.total;
          _facets = result.facets;
          _priceBounds = result.price ?? _priceBounds;
          _sortOptions = result.sortOptions;
        });
      });
    }
    return result;
  }

  Future<void> _openFilters() async {
    Haptics.light();
    final updated = await showZbSheet<ListingQuery>(
      context,
      builder: (_) => FacetSheet(
        query: _query,
        facets: _facets,
        priceBounds: _priceBounds,
      ),
    );
    if (updated != null && mounted) setState(() => _query = updated);
  }

  Future<void> _openSort() async {
    Haptics.light();
    final chosen = await showZbSheet<String>(
      context,
      builder: (_) => SortSheet(options: _sortOptions, selected: _query.orderBy),
    );
    if (chosen != null && mounted) {
      setState(() => _query = _query.copyWith(orderBy: chosen));
    }
  }

  /// Hearts settle on the first frame instead of popping in a beat later.
  /// Deferred past build: seeding writes to a provider the cards are watching.
  void _seedHearts(List<ProductCard> cards) {
    if (cards.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(wishlistControllerProvider.notifier).seedFrom(cards);
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(brandPageProvider(widget.slug));

    if (page.hasValue) return _loaded(page.requireValue);

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: page.hasError
          ? ErrorState(
              error: page.error,
              onRetry: () => ref.invalidate(brandPageProvider(widget.slug)),
            )
          : const BrandPageSkeleton(stageHeight: 160),
    );
  }

  Widget _loaded(BrandPage brand) {
    final l = L.of(context);
    final curated = brand.products;
    final unscoped = _query.category == null && !_query.hasFilters;
    if (unscoped) _seedHearts(curated);

    // The stage runs behind the status bar, so the clock goes light while it
    // is there and flips back the moment the plain bar takes over.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: !_collapsed || context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: PaginatedProductGrid(
            // The whole scope is the reset key: a department chip, a facet or
            // a sort change each restart paging rather than appending page 2
            // of one query onto page 1 of another.
            resetKey: _query,
            fetchPage: _fetch,
            zone: 'brand',
            onAdd: (product) =>
                addToCart(context, ref, product: product, zone: 'brand', quiet: true),
            leadingSlivers: [
              _StageBar(
                page: brand,
                collapsed: _collapsed,
                expandedHeight: _stage,
                activeFilters: _query.activeFilterCount,
                onSort: _sortOptions.isEmpty ? null : _openSort,
                onFilters:
                    _facets.isEmpty && _priceBounds == null ? null : _openFilters,
              ),

              // The crest (logo + name) is painted inside the stage above — a
              // pinned app bar paints over later slivers, so nothing straddles
              // its edge. Down here: the words and the facts.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16),
                  child: BrandIdentity(page: brand),
                ),
              ),

              if (brand.tiles.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: BrandTilesStrip(tiles: brand.tiles),
                  ),
                ),

              if (brand.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: BrandCategoryChips(
                      page: brand,
                      selected: _query.category,
                      onSelect: (slug) => setState(() => _query = slug == null
                          ? _query.copyWith(clearCategory: true)
                          : _query.copyWith(category: slug)),
                    ),
                  ),
                ),

              // The brand's own picks lead, but only on «الكل»: inside a
              // department they would be showing cat food above a dog shelf.
              if (unscoped && curated.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 4),
                    child: ProductRailView(
                      title: l.brandCurated(brand.name),
                      products: curated,
                      zone: 'brand_curated',
                      onAdd: (product) => addToCart(
                        context,
                        ref,
                        product: product,
                        zone: 'brand_curated',
                        quiet: true,
                      ),
                    ),
                  ),
                ),
            ],
            // On «الكل» the heading is what separates the brand's picks from
            // its catalogue. Inside a department the selected chip already says
            // where you are, so only the count — which is new information —
            // survives.
            header: _GridHeader(
              title: unscoped ? l.brandShopAll(brand.name) : null,
              total: _total,
            ),
            emptyState: EmptyState(
              icon: Icons.search_off_rounded,
              title: l.listingEmpty,
              message: l.listingEmptyHint,
              actionLabel: unscoped ? null : l.brandAllCategories,
              onAction: unscoped
                  ? null
                  : () => setState(
                      () => _query = _query.cleared().copyWith(clearCategory: true)),
            ),
          ),
        ),
      ),
    );
  }
}

/// What sits between the brand's own picks and its whole catalogue: a title
/// while the page is unfiltered, and the honest size of whatever scope is
/// currently selected.
class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.title, required this.total});

  final String? title;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: title == null ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 4),
              child: Text(title!, style: context.tt.titleLarge),
            ),
          if (total > 0) ResultCount(total: total),
        ],
      ),
    );
  }
}

/// The collapsing stage.
///
/// The app bar's own background is the page surface; the stage sits in the
/// flexible space and fades out as it collapses, which is what turns the hero
/// into a plain bar without a hard color switch. The controls carry their own
/// scrim disc while they are over artwork and shed it once they are over the
/// surface — one tween, so Reduce Motion collapses it to an instant swap.
class _StageBar extends StatelessWidget {
  const _StageBar({
    required this.page,
    required this.collapsed,
    required this.expandedHeight,
    this.activeFilters = 0,
    this.onSort,
    this.onFilters,
  });

  final BrandPage page;
  final bool collapsed;
  final double expandedHeight;
  final int activeFilters;
  final VoidCallback? onSort;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      // The page's own ground, not `surface`: once collapsed this has to be
      // indistinguishable from every other app bar in the app, and from the
      // grid scrolling underneath it.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 60,
      leading: _StageAction(
        collapsed: collapsed,
        icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onTap: () => context.pop(),
      ),
      actions: [
        if (onSort != null)
          _StageAction(
            collapsed: collapsed,
            icon: Icons.swap_vert_rounded,
            tooltip: L.of(context).listingSort,
            onTap: onSort!,
          ),
        if (onFilters != null)
          _StageAction(
            collapsed: collapsed,
            icon: Icons.tune_rounded,
            tooltip: L.of(context).listingFilters,
            badge: activeFilters > 0,
            onTap: onFilters!,
          ),
        const SizedBox(width: 6),
      ],
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: context.motion(Motion.select),
        curve: Motion.decelerate,
        child: Text(
          page.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.tt.titleLarge,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: BrandStage(page: page),
      ),
    );
  }
}

/// A stage control: a glyph that keeps its own contrast wherever it lands.
class _StageAction extends StatelessWidget {
  const _StageAction({
    required this.collapsed,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge = false,
  });

  final bool collapsed;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// A live-filters dot on the glyph.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return TweenAnimationBuilder<double>(
      // begin only matters on the very first build; afterwards the builder
      // tweens from wherever it is to the new end, which is what makes the
      // swap read as one motion instead of a flicker.
      tween: Tween(begin: collapsed ? 1.0 : 0.0, end: collapsed ? 1.0 : 0.0),
      duration: context.motion(Motion.select),
      curve: Motion.decelerate,
      builder: (context, t, _) => Center(
        child: Material(
          color: Color.lerp(Colors.black.withValues(alpha: 0.30), Colors.transparent, t),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: onTap,
            tooltip: tooltip,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Color.lerp(Colors.white, cs.onSurface, t)),
                if (badge)
                  PositionedDirectional(
                    top: -2,
                    end: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.zb.sale,
                        border: Border.all(color: cs.surface, width: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
