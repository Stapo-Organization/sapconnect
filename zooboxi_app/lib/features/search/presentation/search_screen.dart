import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/navigation/active_branch.dart';
import '../../../core/providers.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/zb_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/icons/facet_sticker.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/shelf/shelf_controller.dart';
import '../../brand/data/brand_activation.dart';
import '../../brand/presentation/widgets/brand_activation_widgets.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';
import '../../pets/data/household.dart';
import 'search_transition.dart';

/// Search: a debounced suggest list, recent queries, and a route to the
/// scanner.
///
/// Suggestions are cancelled on every keystroke — a store this size answers in
/// well under the typing interval, and letting stale responses land is how a
/// suggest list ends up showing results for a prefix you already deleted.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _debouncer = Debouncer(duration: const Duration(milliseconds: 280));

  /// The route's own transition, watched so the keyboard is asked for once —
  /// and only after the field has finished flying in from the home button.
  /// Focusing during the flight opens the keyboard against a widget the Hero
  /// is about to swap for its placeholder, and it bounces.
  Animation<double>? _entrance;
  bool _asked = false;

  CancelToken? _inFlight;
  List<SearchSuggestion> _suggestions = const [];

  /// The brand the query names — «اينابا» is a brand before it is eight products.
  BrandSummary? _brand;
  bool _loading = false;
  String _query = '';

  /// What this person has bought, shown before they type a letter. The most
  /// powerful search result is the thing they bought last month.
  List<SearchSuggestion> _bought = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBought());
  }

  Future<void> _loadBought() async {
    if (!ref.read(isAuthenticatedProvider)) return;
    try {
      // An empty query asks the store for the customer's own purchases.
      final rows = await ref.read(catalogRepositoryProvider).suggest('');
      if (mounted) setState(() => _bought = rows.where((r) => r.bought).toList());
    } catch (_) {
      // Nothing to show is the ordinary state for a new customer.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked || _entrance != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _askForKeyboard();
      return;
    }
    _entrance = animation..addStatusListener(_onEntrance);
  }

  void _onEntrance(AnimationStatus status) {
    if (status == AnimationStatus.completed) _askForKeyboard();
  }

  void _askForKeyboard() {
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _entrance?.removeStatusListener(_onEntrance);
    _debouncer.dispose();
    _inFlight?.cancel();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    setState(() => _query = query);

    _inFlight?.cancel();
    if (query.length < 2) {
      _debouncer.cancel();
      setState(() {
        _suggestions = const [];
        _brand = null;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debouncer.run(() => _suggest(query));
  }

  Future<void> _suggest(String query) async {
    final token = CancelToken();
    _inFlight = token;
    try {
      final result =
          await ref.read(brandActivationRepositoryProvider).suggest(query, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _suggestions = result.suggestions;
        _brand = result.brand;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _suggestions = const [];
        _brand = null;
        _loading = false;
      });
    }
  }

  Future<void> _submit(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    await ref.read(localStoreProvider).pushRecentSearch(query);
    ref.track(ZbEvent(type: ZbEvents.search, query: query));
    if (!mounted) return;
    unawaited(
      context.push(
        Uri(path: '/listing', queryParameters: {'q': query, 'title': query}).toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final recent = ref.read(localStoreProvider).recentSearches;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        // The far end of the home button's flight: the same pill, landed and
        // typed into. Hero owns the shape while it travels, so what is written
        // here is only what the field looks like once it has arrived.
        title: Hero(
          // The far end of whichever button opened this screen.
          tag: searchHeroTagFor(ref.watch(activeBranchProvider)),
          createRectTween: (begin, end) =>
              MaterialRectArcTween(begin: begin, end: end),
          flightShuttleBuilder: searchFlightShuttle,
          child: Material(
            color: context.cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: ZbIcon(
                        ZbIconKind.search,
                        size: 20,
                        ink: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: l.searchHint,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  _onChanged('');
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.searchScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () {
              Haptics.light();
              context.push('/scan');
            },
          ),
        ],
      ),
      body: _body(l, recent),
    );
  }

  Widget _body(L l, List<String> recent) {
    if (_query.length < 2) {
      return _RecentSearches(
        queries: recent,
        bought: _bought,
        onPick: (query) {
          _controller.text = query;
          _submit(query);
        },
        onClear: () async {
          await ref.read(localStoreProvider).clearRecentSearches();
          if (mounted) setState(() {});
        },
      );
    }

    if (_loading && _suggestions.isEmpty && _brand == null) {
      return const _SuggestSkeleton();
    }

    final brand = _brand;
    final express = ref.watch(resolvedShelfProvider) == Shelf.express;

    if (_suggestions.isEmpty && brand != null) {
      return ListView(
        padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [BrandSearchCard(brand: brand, express: express)],
      );
    }

    if (_suggestions.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l.searchNoSuggestions,
        message: l.listingEmptyHint,
        compact: true,
        actionLabel: l.actionContinue,
        onAction: () => _submit(_query),
      );
    }

    // The brand's card leads; the product suggestions follow it.
    final lead = brand == null ? 0 : 1;
    return ListView.separated(
      padding: EdgeInsets.only(top: lead == 1 ? 8 : 0, bottom: 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: _suggestions.length + 1 + lead,
      separatorBuilder: (_, i) => i < lead
          ? const SizedBox.shrink()
          : Divider(height: 1, color: context.cs.outlineVariant),
      itemBuilder: (context, raw) {
        if (raw < lead) return BrandSearchCard(brand: brand!, express: express);
        final index = raw - lead;
        if (index == _suggestions.length) {
          return ListTile(
            leading: Icon(Icons.search_rounded, color: context.cs.primary),
            title: Text('${L.of(context).searchTitle}: $_query'),
            onTap: () => _submit(_query),
          );
        }
        return _SuggestionTile(suggestion: _suggestions[index]);
      },
    );
  }
}

/// A strip of what they buy, each a tap from its page — the fastest route
/// through the store for someone replacing last month's bag.
class _BoughtRow extends StatelessWidget {
  const _BoughtRow({required this.items});

  final List<SearchSuggestion> items;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => Gap.w10,
        itemBuilder: (context, i) {
          final item = items[i];
          return SizedBox(
            width: 72,
            child: InkWell(
              borderRadius: BorderRadius.circular(ZbTokens.rMd),
              onTap: () {
                Haptics.selection();
                context.push('/product/${item.id}');
              },
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(ZbTokens.rMd),
                    ),
                    child: ZbImage(
                      url: item.image,
                      radius: BorderRadius.circular(ZbTokens.rMd),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.tt.labelSmall?.copyWith(height: 1.15),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion});

  final SearchSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final price = suggestion.price;
    final days = suggestion.lastOrderedDays;

    return ListTile(
      leading: SizedBox(
        width: 46,
        height: 46,
        child: ZbImage(
          url: suggestion.image,
          radius: BorderRadius.circular(ZbTokens.rSm),
          padding: const EdgeInsets.all(4),
        ),
      ),
      title: Text(suggestion.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (price != null) Text(Fmt.price(price, locale: locale)),
          // «اشتريته سابقاً · قبل ١٢ يومًا» — the reason it is at the top.
          if (suggestion.bought) ...[
            if (price != null) Gap.w8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: context.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
              ),
              child: Text(
                days == null ? l.searchBought : '${l.searchBought} · ${l.searchBoughtDays(days)}',
                style: context.tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Haptics.selection();
        context.push('/product/${suggestion.id}');
      },
    );
  }
}

/// «امسح الباركود» as a row, not an icon: the customer holding the bag is
/// looking for words, and the search screen is where they land.
class _ScanRow extends StatelessWidget {
  const _ScanRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: context.isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(ZbTokens.rSm),
                ),
                child: Center(child: ZbIcon(ZbIconKind.scan, size: 20, ink: cs.primary)),
              ),
              Gap.w10,
              // Said as the job it does: the empty bag in the customer's hand
              // becomes the same bag at their door.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.searchScanTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(l.searchScanHint, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «تصفّح كل المنتجات» — for the customer who came to search without a
/// name to type: the whole store, started from the pet and the shelf.
class _BrowseAllRow extends StatelessWidget {
  const _BrowseAllRow();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    return Material(
      color: dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.push('/listing?all=1');
        },
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const FacetSticker('all', size: 34),
              Gap.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.searchBrowseAllTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(l.searchBrowseAllHint, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the screen offers before a word is typed — never a blank page.
///
/// The scan card first (the customer holding an empty bag is the fastest
/// reorder there is), then the whole store, then their own purchases under
/// their pet's name, their recent searches, and what people search for here.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({
    required this.queries,
    required this.onPick,
    required this.onClear,
    this.bought = const [],
  });

  final List<String> queries;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  /// Their own purchases, first — before a word is typed.
  final List<SearchSuggestion> bought;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final popular = ref.watch(popularSearchesProvider).value ?? const PopularSearches();
    final pet = ref.watch(householdProvider).focus;
    final petName = pet == null || pet.name.isEmpty ? null : pet.name;
    // A popular query the customer already has in «recent» is not news.
    final fresh = [
      for (final q in popular.queries)
        if (!queries.any((r) => r.toLowerCase() == q.toLowerCase())) q,
    ];

    Widget chips(List<String> items, IconData icon) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in items)
              ActionChip(
                avatar: Icon(icon, size: 15, color: cs.onSurfaceVariant),
                label: Text(query),
                onPressed: () => onPick(query),
              ),
          ],
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _ScanRow(onTap: () {
          Haptics.light();
          context.push('/scan');
        }),
        Gap.h8,
        const _BrowseAllRow(),
        if (bought.isNotEmpty) ...[
          Gap.h16,
          Text(petName != null ? l.searchForPet(petName) : l.searchBought, style: context.tt.titleSmall),
          Gap.h8,
          _BoughtRow(items: bought),
        ],
        if (queries.isNotEmpty) ...[
          Gap.h12,
          Row(
            children: [
              Expanded(child: Text(l.searchRecent, style: context.tt.titleSmall)),
              TextButton(onPressed: onClear, child: Text(l.searchClearRecent)),
            ],
          ),
          Gap.h8,
          chips(queries, Icons.history_rounded),
        ],
        if (fresh.isNotEmpty) ...[
          Gap.h16,
          // Honest title: «الأكثر بحثاً» only when searches made the list; the
          // store's biggest brands are an invitation, not a statistic.
          Text(popular.fromSearches ? l.searchPopular : l.searchTry, style: context.tt.titleSmall),
          Gap.h8,
          chips(fresh, popular.fromSearches ? Icons.trending_up_rounded : Icons.search_rounded),
        ],
      ],
    );
  }
}

class _SuggestSkeleton extends StatelessWidget {
  const _SuggestSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SkeletonBox(width: 46, height: 46, radius: ZbTokens.rSm),
                SizedBox(width: 14),
                Expanded(child: SkeletonBox(height: 13)),
              ],
            ),
          ),
        ),
      );
}
