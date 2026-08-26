import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/paginated_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import 'widgets/facet_sheet.dart';
import 'widgets/sort_sheet.dart';

/// A filtered product grid — the screen behind every category, brand, rail
/// "see all" and search result.
///
/// The query is the screen's state; the grid keys off it, so applying a filter
/// resets paging rather than appending page 2 of the old query onto page 1 of
/// the new one.
class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key, required this.query, this.title = ''});

  final ListingQuery query;
  final String title;

  @override
  ConsumerState<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends ConsumerState<ListingScreen> {
  late ListingQuery _query = widget.query;

  /// Facets and price bounds describe the *current* result set, so they are
  /// captured from whichever page-1 response came back last.
  List<FacetGroup> _facets = const [];
  PriceFacet? _priceBounds;
  List<SortOption> _sortOptions = const [];
  int _total = 0;

  Future<ListingResult> _fetch(int page) async {
    final result = await ref.read(catalogRepositoryProvider).products(_query, page);
    if (mounted && page == 1) {
      // Deferred: this runs inside the grid's build/fetch cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _facets = result.facets;
          _priceBounds = result.price ?? _priceBounds;
          _sortOptions = result.sortOptions;
          _total = result.total;
        });
      });
    }
    ref.read(wishlistControllerProvider.notifier).seedFrom(result.products);
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

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = widget.title.isNotEmpty
        ? widget.title
        : (_query.q ?? l.categoriesTitle);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PaginatedProductGrid(
        // Both the query and the visible facet set feed the reset key: a new
        // query must restart paging, and nothing else should.
        resetKey: _query,
        fetchPage: _fetch,
        zone: 'listing',
        onAdd: (product) => addToCart(context, ref, product: product, zone: 'listing', quiet: true),
        header: _Toolbar(
          total: _total,
          activeFilters: _query.activeFilterCount,
          sortLabel: _sortLabel(l),
          onFilters: _facets.isEmpty && _priceBounds == null ? null : _openFilters,
          onSort: _sortOptions.isEmpty ? null : _openSort,
        ),
        emptyState: EmptyState(
          icon: Icons.search_off_rounded,
          title: l.listingEmpty,
          message: l.listingEmptyHint,
          actionLabel: _query.hasFilters ? l.listingClearFilters : null,
          onAction: _query.hasFilters
              ? () => setState(() => _query = _query.cleared())
              : null,
        ),
      ),
    );
  }

  String? _sortLabel(L l) {
    final key = _query.orderBy;
    if (key == null) return null;
    for (final option in _sortOptions) {
      if (option.key == key) return option.label;
    }
    return null;
  }
}

/// Filter / sort bar pinned above the grid.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.total,
    required this.activeFilters,
    required this.sortLabel,
    required this.onFilters,
    required this.onSort,
  });

  final int total;
  final int activeFilters;
  final String? sortLabel;
  final VoidCallback? onFilters;
  final VoidCallback? onSort;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  activeFilters > 0
                      ? l.listingFiltersActive(activeFilters)
                      : l.listingResults(total),
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              if (onSort != null)
                _ToolButton(
                  icon: Icons.swap_vert_rounded,
                  label: sortLabel ?? l.listingSort,
                  onTap: onSort!,
                ),
              if (onFilters != null) ...[
                Gap.w8,
                _ToolButton(
                  icon: Icons.tune_rounded,
                  label: l.listingFilters,
                  badge: activeFilters,
                  onTap: onFilters!,
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        Gap.h8,
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final active = badge > 0;

    return Material(
      color: active ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              Gap.w6,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelMedium?.copyWith(
                    color: active ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              if (active) ...[
                Gap.w6,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: context.tt.labelSmall?.copyWith(
                      color: cs.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
