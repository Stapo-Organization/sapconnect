import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/motion/motion.dart';
import '../../../core/shelf/shelf_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/paginated_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/widgets/facet_sheet.dart';
import '../../catalog/presentation/widgets/filter_bar.dart';
import '../../catalog/presentation/widgets/filtered_empty.dart';
import '../../catalog/presentation/widgets/sort_sheet.dart';
import '../../wishlist/data/wishlist_controller.dart';
import 'widgets/brand_about_sheet.dart';
import 'widgets/brand_activation_widgets.dart';
import 'widgets/brand_palette.dart';
import 'widgets/brand_sections.dart';
import 'widgets/brand_shelves.dart';
import 'widgets/brand_stage.dart';

/// A brand's page — «الواجهة», its storefront inside Zooboxi.
///
/// Because a brand is how many pet owners shop — they bought INABA once and
/// they are looking for INABA again — the page is the brand's, not the
/// store's: its colour on the stage, its logo and its own line, the Zooboxi
/// animal the brand is made for peeking over the page, then its facts, its
/// product lines as picture tiles, where its bigger pack is honestly cheaper,
/// and its whole range under the same pinned filter bar every listing has.
/// Its story lives one tap away, in «عن …».
///
/// One scroll view: the grid owns the scroll (see
/// [PaginatedProductGrid.leadingSlivers]). Everything rich is conditional —
/// a brand with no identity on file still gets a page that looks finished,
/// in the store's own colour.
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
  /// The grid's whole scope: brand always, plus the facet picks and the sort.
  late ListingQuery _query = ListingQuery(brand: widget.slug);

  /// Facets and sorts describe the *current* result set, captured from
  /// whichever page-1 response came back last, as a listing does.
  ListingFacets _facets = ListingFacets.empty;
  List<SortOption> _sortOptions = const [];
  int _total = 0;
  bool _loaded = false;

  /// True once the stage has scrolled away and the bar is the brand's strip.
  bool _collapsed = false;

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

  bool _onScroll(ScrollNotification notification, double stage) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) return false;
    final collapsed = notification.metrics.pixels > stage - kToolbarHeight - 8;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  Future<ListingResult> _fetch(int page) async {
    final result = await ref.read(catalogRepositoryProvider).products(_query, page);
    if (page == 1) {
      // Deferred: this runs inside the grid's own build/fetch cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (!result.facets.isEmpty || result.total == 0) _facets = result.facets;
          _sortOptions = result.sortOptions;
          _total = result.total;
          _loaded = true;
        });
      });
    }
    ref.read(wishlistControllerProvider.notifier).seedFrom(result.products);
    return result;
  }

  void _setQuery(ListingQuery next) {
    if (next == _query) return;
    setState(() => _query = next);
  }

  /// A line tile is one choice at a time: tapping another line moves the
  /// ring, tapping the ringed one lets the whole brand back.
  void _toggleShelf(BrandShelf shelf) {
    Haptics.selection();
    final on = _query.isSelected(shelf.group, shelf.key) && _query.filters[shelf.group]!.length == 1;
    _setQuery(_query.withGroup(shelf.group, on ? const {} : {shelf.key}));
  }

  Future<void> _openFilters({String? group}) async {
    Haptics.light();
    final updated = await showZbSheet<ListingQuery>(
      context,
      builder: (_) => FacetSheet(query: _query, facets: _facets, total: _total, initialGroup: group),
    );
    if (updated != null && mounted) _setQuery(updated);
  }

  Future<void> _openSort() async {
    Haptics.light();
    final chosen = await showZbSheet<String>(
      context,
      builder: (_) => SortSheet(options: _sortOptions, selected: _query.orderBy),
    );
    if (chosen != null && mounted) _setQuery(_query.copyWith(orderBy: chosen));
  }

  void _openAbout(BrandPage page, BrandPalette palette) {
    Haptics.light();
    ref.track(ZbEvent(type: ZbEvents.view, zone: 'brand_about', payload: {'brand': widget.slug}));
    showZbSheet<void>(
      context,
      builder: (sheet) => BrandAboutSheet(
        page: page,
        palette: palette,
        onShopAll: () {
          Navigator.of(sheet).pop();
          _setQuery(_query.cleared());
        },
      ),
    );
  }

  String? _sortLabel() {
    final key = _query.orderBy;
    if (key == null) return null;
    for (final option in _sortOptions) {
      if (option.key == key) return option.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(brandPageProvider(widget.slug));

    if (page.hasValue) return _page(page.requireValue);

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: page.hasError
          ? ErrorState(
              error: page.error,
              onRetry: () => ref.invalidate(brandPageProvider(widget.slug)),
            )
          : const BrandPageSkeleton(stageHeight: 300),
    );
  }

  Widget _page(BrandPage brand) {
    final l = L.of(context);
    final palette = BrandPalette.of(context, brand);
    final express = ref.watch(resolvedShelfProvider) == Shelf.express;
    final stage = brandStageHeight(express: express);
    final unscoped = !_query.hasFilters;
    final hasAbout = brand.hasKit &&
        ((brand.lead ?? '').isNotEmpty || brand.mood.isNotEmpty || (brand.country ?? '').isNotEmpty);
    final onAbout = hasAbout ? () => _openAbout(brand, palette) : null;
    final value = brand.value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.fieldIsLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onScroll(n, stage),
          child: PaginatedProductGrid(
            // The whole scope is the reset key: a line, a facet or a sort
            // change restarts paging rather than appending page 2 of one
            // query onto page 1 of another.
            resetKey: _query,
            fetchPage: _fetch,
            zone: 'brand',
            onAdd: (product) => addToCart(context, ref, product: product, zone: 'brand', quiet: true),
            leadingSlivers: [
              _StageBar(
                page: brand,
                palette: palette,
                collapsed: _collapsed,
                expandedHeight: stage,
                express: express,
                onAbout: onAbout,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
                  child: BrandFacts(page: brand, palette: palette),
                ),
              ),
              if (brand.mood.isNotEmpty || onAbout != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 0),
                    child: BrandMoodRow(page: brand, palette: palette, onAbout: onAbout),
                  ),
                ),
              if (brand.tiles.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: BrandTilesStrip(tiles: brand.tiles),
                  ),
                ),
              if (brand.shelvesToShow.length >= 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: BrandShelvesRail(
                      page: brand,
                      palette: palette,
                      isSelected: (s) => _query.isSelected(s.group, s.key),
                      onSelect: _toggleShelf,
                    ),
                  ),
                ),
              // The saving belongs to the whole brand; inside a filter it
              // could point at a pack the grid no longer shows.
              if (unscoped && value != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
                    child: BrandValueBand(value: value, palette: palette),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverPersistentHeader(
                pinned: true,
                delegate: FilterBarDelegate(
                  query: _query,
                  facets: _facets,
                  sortLabel: _sortLabel(),
                  onFilters: _facets.isEmpty ? null : () => _openFilters(),
                  onSort: _sortOptions.isEmpty ? null : _openSort,
                  onToggle: (group, value) => _setQuery(_query.toggled(group, value)),
                  onClearPrice: () => _setQuery(_query.copyWith(clearPrice: true)),
                  onClearAll: () => _setQuery(_query.cleared()),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ],
            header: _GridHeader(
              title: unscoped ? l.brandShopAll(brand.name) : null,
              total: _loaded ? _total : 0,
              inStock: unscoped ? brand.inStock : 0,
              express: express,
            ),
            emptyState: _query.hasFilters
                ? FilteredEmpty(query: _query, facets: _facets, onQuery: _setQuery)
                : EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l.listingEmpty,
                    message: l.listingEmptyHint,
                    mascot: true,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Between the brand's shelves and its whole range: a title while the page is
/// unfiltered, and the honest size of whatever is selected — on إكسبريس, how
/// much of it reaches the door within two hours.
class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.title, required this.total, required this.inStock, required this.express});

  final String? title;
  final int total;
  final int inStock;
  final bool express;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final String? line;
    if (total <= 0) {
      line = null;
    } else if (express) {
      line = l.brandExpressReady(total);
    } else if (inStock > 0 && inStock < total) {
      line = '${l.filterProductCount(total)} · ${l.brandInStock(inStock)}';
    } else {
      line = l.filterProductCount(total);
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title!, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (line != null)
            Text(
              line,
              style: (title != null ? context.tt.bodySmall : context.tt.titleSmall)?.copyWith(
                color: title != null ? cs.onSurfaceVariant : null,
                fontWeight: title != null ? null : FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

/// The collapsing stage. Expanded it is the brand's storefront; collapsed it
/// is a strip in the brand's colour carrying its logo, name and size — the
/// page never turns into a plain bar, so the customer always knows whose
/// shelf they are on.
class _StageBar extends StatelessWidget {
  const _StageBar({
    required this.page,
    required this.palette,
    required this.collapsed,
    required this.expandedHeight,
    required this.express,
    this.onAbout,
  });

  final BrandPage page;
  final BrandPalette palette;
  final bool collapsed;
  final double expandedHeight;
  final bool express;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = page.shelfTotal > 0 ? page.shelfTotal : page.productCount;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: palette.field,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 60,
      leading: _StageButton(
        icon: context.isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onTap: () => context.pop(),
      ),
      actions: [
        // Follow: the brand's new products come to the customer.
        if (page.brand.slug.isNotEmpty) ...[
          FollowBrandButton.disc(slug: page.brand.slug, name: page.name),
          const SizedBox(width: 8),
        ],
        if (onAbout != null)
          _StageButton(icon: Icons.info_outline_rounded, tooltip: l.brandAbout(page.name), onTap: onAbout!),
        const SizedBox(width: 10),
      ],
      titleSpacing: 0,
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: context.motion(Motion.select),
        curve: Motion.decelerate,
        child: Row(
          children: [
            BrandLogoPlate(page: page, width: 46, height: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    page.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(color: palette.ink, fontWeight: FontWeight.w900),
                  ),
                  if (total > 0)
                    Text(
                      [
                        l.brandProductCount(total),
                        if ((page.country ?? '').isNotEmpty) page.country!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelSmall?.copyWith(
                        color: palette.ink.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: BrandStage(page: page, palette: palette, express: express),
      ),
    );
  }
}

/// A stage control: a white disc that reads on any brand colour.
class _StageButton extends StatelessWidget {
  const _StageButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: const Color(0xFF1F2A22)),
        ),
      ),
    );
  }
}
