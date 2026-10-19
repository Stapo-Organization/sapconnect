import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/characters/scenes.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/paginated_grid.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../data/pet_fit.dart';
import '../../pets/data/household.dart';
import '../../pets/data/pet_models.dart';
import 'widgets/all_products_head.dart';
import 'widgets/category_chips.dart';
import 'widgets/facet_sheet.dart';
import 'widgets/filter_bar.dart';
import 'widgets/filtered_empty.dart';
import 'widgets/pet_fit_banner.dart';
import 'widgets/sort_sheet.dart';

/// A filtered product grid — the screen behind every category, brand, rail
/// "see all" and search result.
///
/// «اللوحة»: the store's department row, a pinned filter bar (filter +
/// sort + promoted values + what is applied), the pet's own filter
/// («نعرض المناسب لـ مشمش»), and an empty state that knows which tap brings
/// results back. The facets come from the store's facet index, scoped to
/// this list and counted against the other picks.
class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key, required this.query, this.title = '', this.allProducts = false});

  final ListingQuery query;
  final String title;

  /// «كل المنتجات»: the whole store, headed by the pet tabs and the shelf
  /// row, best sellers first, opened on the family's pet when the family
  /// is all one kind.
  final bool allProducts;

  /// The facets the all-products head draws as its own rows.
  static const headGroups = {'species', 'dept'};

  @override
  ConsumerState<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends ConsumerState<ListingScreen> {
  late ListingQuery _query = widget.allProducts ? _allProductsStart(widget.query) : widget.query;

  /// «كل المنتجات» opens on the pet when every pet at home is one kind
  /// (two cats → قطط; a cat and a dog → الكل), and on the best sellers —
  /// «الأنسب» over the whole store starts with a milk and a 3 ﷼ scoop.
  ListingQuery _allProductsStart(ListingQuery query) {
    var next = query.orderBy == null ? query.copyWith(orderBy: 'popularity') : query;
    if (next.filters.containsKey('species')) return next;
    final kinds = ref.read(householdProvider).species;
    final key = kinds.length == 1 ? _storeSpecies(kinds.first) : null;
    if (key != null) next = next.withGroup('species', {key});
    return next;
  }

  static String? _storeSpecies(PetSpecies species) => switch (species) {
        PetSpecies.cat => 'cat',
        PetSpecies.dog => 'dog',
        PetSpecies.bird => 'bird',
        PetSpecies.small => 'small',
        _ => null,
      };

  /// Restarts the grid. Bumped on every change the customer makes — but not
  /// when the pet's own filter is folded into the first fetch, which already
  /// returned the narrowed page.
  int _version = 0;

  /// Follows the department chosen in the chip row; starts as the title the
  /// caller pushed with.
  late String _title = widget.title;

  /// Facets and sorts describe the *current* result set, so they are
  /// captured from whichever page-1 response came back last.
  ListingFacets _facets = ListingFacets.empty;
  List<SortOption> _sortOptions = const [];
  ListingContext? _context;
  int _total = 0;
  bool _loaded = false;

  /// The pet filter is decided once per department, on its first page.
  bool _petDecided = false;

  /// The customer switched the pet filter off here — it stays off.
  bool _petDeclined = false;

  Future<ListingResult> _fetch(int page) async {
    final repository = ref.read(catalogRepositoryProvider);
    var query = _query;
    var result = await repository.products(query, page);

    if (page == 1 && !_petDecided) {
      _petDecided = true;
      final narrowed = _petQuery(query, result.facets);
      if (narrowed != null) {
        query = narrowed;
        _query = narrowed;
        result = await repository.products(query, 1);
      }
    }

    if (mounted && page == 1) {
      // Deferred: this runs inside the grid's build/fetch cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          if (!result.facets.isEmpty || result.total == 0) _facets = result.facets;
          _sortOptions = result.sortOptions;
          _context = result.context ?? _context;
          _total = result.total;
          _loaded = true;
        });
      });
    }
    ref.read(wishlistControllerProvider.notifier).seedFrom(result.products);
    return result;
  }

  /// The first page's query with the pet's life stage folded in — when a pet
  /// of this aisle's species lives here, its age is known, the aisle sorts by
  /// age at all, and the customer has not chosen an age themselves.
  ListingQuery? _petQuery(ListingQuery query, ListingFacets facets) {
    if (_petDeclined || query.filters.containsKey('life')) return null;
    final fit = ref.read(petFitProvider(facets.speakAs));
    final life = fit?.life;
    if (life == null) return null;
    final group = facets.group('life');
    final value = group?.values.where((v) => v.key == life).firstOrNull;
    if (value == null || value.count == 0) return null;
    return query.withGroup('life', {life});
  }

  void _setQuery(ListingQuery next) {
    if (next == _query) return;
    // Taking the age off by hand (a chip's ✕, the sheet) is a «no thanks»
    // to the pet filter, just like its switch.
    if (_query.filters.containsKey('life') && !next.filters.containsKey('life')) _petDeclined = true;
    // On «كل المنتجات» the pet's age waits for the food shelf; once food is
    // picked it is folded in the way a food aisle folds it on arrival.
    final foodNow = next.isSelected('dept', 'food') || next.isSelected('dept', 'treat');
    final foodBefore = _query.isSelected('dept', 'food') || _query.isSelected('dept', 'treat');
    if (widget.allProducts && foodNow && !foodBefore) _petDecided = false;
    setState(() {
      _query = next;
      _version++;
    });
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

  /// A department from the chip row. The picks travel with the customer —
  /// the pet's age and a flavour mean the same thing one aisle over — and
  /// the empty state offers the way back if they no longer fit.
  void _switchCategory(String slug, String title) {
    setState(() {
      _query = _query.copyWith(category: slug);
      _title = title;
      _version++;
      _petDecided = false;
    });
  }

  void _togglePet(PetFit fit, bool on) {
    if (on) {
      _petDeclined = false;
      _setQuery(_query.withGroup('life', {fit.life!}));
    } else {
      _petDeclined = true;
      _setQuery(_query.withGroup('life', const {}));
    }
  }

  Future<void> _answerAge(PetFit fit, String life) async {
    await ref.read(petLifeAnswersProvider.notifier).answer(fit.memberKey, life);
    if (!mounted) return;
    _petDeclined = false;
    _setQuery(_query.withGroup('life', {life}));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final title = _title.isNotEmpty ? _title : (widget.allProducts ? l.allProductsTitle : (_query.q ?? l.categoriesTitle));
    final lifeGroup = _facets.group('life');
    final fit = lifeGroup == null ? null : ref.watch(petFitProvider(_facets.speakAs));
    final petActive = fit?.life != null && _query.filters['life']?.length == 1 && _query.isSelected('life', fit!.life!);
    final showPet = fit != null && (fit.life == null || lifeGroup!.values.any((v) => v.key == fit.life));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_loaded)
              Text(
                l.filterProductCount(_total),
                style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: PaginatedProductGrid(
        resetKey: _version,
        fetchPage: _fetch,
        zone: 'listing',
        onAdd: (product) => addToCart(
          context,
          ref,
          product: product,
          zone: 'listing',
          quiet: true,
        ),
        leadingSlivers: [
          if (widget.allProducts)
            SliverToBoxAdapter(
              child: AllProductsHead(query: _query, facets: _facets, onQuery: _setQuery),
            ),
          if (_context != null && _context!.chips.isNotEmpty)
            SliverToBoxAdapter(
              child: ContextChips(context: _context!, species: _facets.species, onSelect: _switchCategory),
            ),
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
              onClearAll: () => _setQuery(widget.allProducts ? _clearedKeepingHead() : _query.cleared()),
              textScaler: MediaQuery.textScalerOf(context),
              headerGroups: widget.allProducts ? ListingScreen.headGroups : const {},
            ),
          ),
        ],
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPet)
              PetFitBanner(
                fit: fit,
                active: petActive,
                lifeGroup: lifeGroup,
                onToggle: (on) => _togglePet(fit, on),
                onAnswer: (life) => _answerAge(fit, life),
              ),
            if (_loaded && _total > 0)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        petActive ? l.petFilterMatch(_total, PetFitBanner.nameOf(l, fit)) : l.filterProductCount(_total),
                        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (petActive)
                      TextButton(
                        onPressed: () => _togglePet(fit, false),
                        child: Text(l.petFilterShowAll),
                      ),
                  ],
                ),
              ),
          ],
        ),
        emptyState: _query.hasFilters
            ? FilteredEmpty(query: _query, facets: _facets, onQuery: _setQuery)
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l.listingEmpty,
                message: l.listingEmptyHint,
                // A search that found nothing: the animal points at the words.
                // Any other empty shelf keeps the peek.
                scene: (_query.q?.trim().isNotEmpty ?? false) ? SearchScene(query: _query.q) : null,
                mascot: true,
              ),
      ),
    );
  }

  /// «مسح الكل» under the pet tabs clears the filters, not the pet and the
  /// shelf the head shows as picked.
  ListingQuery _clearedKeepingHead() {
    var next = _query.cleared();
    for (final key in ListingScreen.headGroups) {
      final values = _query.filters[key];
      if (values != null) next = next.withGroup(key, values);
    }
    return next;
  }

  String? _sortLabel() {
    final key = _query.orderBy;
    if (key == null) return null;
    for (final option in _sortOptions) {
      if (option.key == key) return option.label;
    }
    return null;
  }
}
