import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/zb_colors.dart';
import '../../features/catalog/data/catalog_models.dart';
import '../../features/catalog/data/product_models.dart';
import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import 'error_state.dart';
import 'product_card.dart';
import 'product_card_metrics.dart';
import 'skeleton.dart';

/// Two-column infinite product grid.
///
/// Owns paging imperatively rather than through a provider family, because a
/// listing's pages are append-only scroll state, not cacheable derived data —
/// modelling them as providers means page 4 disappearing when page 1 refreshes.
///
/// Change [resetKey] (e.g. to the current filters) to hard-reset paging.
class PaginatedProductGrid extends StatefulWidget {
  const PaginatedProductGrid({
    super.key,
    required this.fetchPage,
    required this.resetKey,
    this.header,
    this.emptyState,
    this.onAdd,
    this.zone,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 28),
  });

  final Future<ListingResult> Function(int page) fetchPage;

  /// Rebuilding with a different value restarts paging from page 1.
  final Object resetKey;

  /// Pinned above the grid, inside the same scroll view.
  final Widget? header;
  final Widget? emptyState;
  final Future<void> Function(ProductCard product)? onAdd;
  final String? zone;
  final EdgeInsets padding;

  @override
  State<PaginatedProductGrid> createState() => _PaginatedProductGridState();
}

class _PaginatedProductGridState extends State<PaginatedProductGrid> {
  final _controller = ScrollController();
  final List<ProductCard> _items = [];

  int _page = 1;
  int _lastPage = 1;
  bool _firstLoading = true;
  bool _loadingMore = false;
  Object? _error;
  Object? _moreError;

  /// Guards against a stale in-flight page landing after the filters changed.
  int _generation = 0;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void didUpdateWidget(covariant PaginatedProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      if (_controller.hasClients) _controller.jumpTo(0);
      _loadFirst();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_controller.position.extentAfter < 600) _loadMore();
  }

  Future<void> _loadFirst() async {
    final generation = ++_generation;
    setState(() {
      _firstLoading = _items.isEmpty;
      _error = null;
      _moreError = null;
    });
    try {
      final result = await widget.fetchPage(1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.products);
        _page = result.page;
        _lastPage = result.pages;
        _firstLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _firstLoading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _firstLoading || !_hasMore || _error != null || _moreError != null) {
      return;
    }
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.fetchPage(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.products);
        _page = result.page;
        _lastPage = result.pages;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _moreError = e;
      });
    }
  }

  Future<void> refresh() => _loadFirst();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: _loadFirst,
      edgeOffset: 8,
      child: CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
          ..._body(),
        ],
      ),
    );
  }

  List<Widget> _body() {
    if (_firstLoading) {
      // The skeleton owns the padding rather than being wrapped in it, so the
      // tile width it computes its height from is the one it is actually
      // given — otherwise the placeholders come out taller than the cards
      // that replace them, and the first page lands with a jump.
      return [
        SliverToBoxAdapter(child: SkeletonProductGrid(padding: widget.padding)),
      ];
    }

    if (_error != null && _items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(error: _error, onRetry: _loadFirst),
        ),
      ];
    }

    if (_items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: widget.emptyState ?? const SizedBox.shrink(),
        ),
      ];
    }

    final reduceMotion = context.reduceMotion;

    return [
      SliverPadding(
        padding: widget.padding,
        sliver: SliverGrid(
          // The card computes its own height from its slots; asking for that
          // exact extent is what keeps a long name or a big type size from
          // pushing the add button out of the tile.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: ProductCardMetrics.gridSpacing,
            crossAxisSpacing: ProductCardMetrics.gridSpacing,
            mainAxisExtent: ProductCardMetrics.gridExtent(
              context,
              horizontalPadding: widget.padding.horizontal,
            ),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final card = ProductCardView(
                product: _items[index],
                onAdd: widget.onAdd,
                zone: widget.zone,
              );
              if (reduceMotion) return card;
              // Only the first screenful staggers; below the fold it would
              // just look like the list is loading slowly.
              return card
                  .animate()
                  .fadeIn(
                    duration: 240.ms,
                    delay: Motion.stagger * (index % 6),
                    curve: Curves.easeOut,
                  )
                  .moveY(begin: 12, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
            },
            childCount: _items.length,
          ),
        ),
      ),
      SliverToBoxAdapter(child: _footer()),
    ];
  }

  Widget _footer() {
    if (_moreError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() => _moreError = null);
              _loadMore();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(L.of(context).actionRetry),
          ),
        ),
      );
    }
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 28),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }
    return const SizedBox(height: 12);
  }
}

/// Result-count line shown above a grid.
class ResultCount extends StatelessWidget {
  const ResultCount({super.key, required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 4),
        child: Text(
          L.of(context).listingResults(total),
          style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
        ),
      );
}
