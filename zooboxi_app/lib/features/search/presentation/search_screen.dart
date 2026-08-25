import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/providers.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/zb_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/data/product_models.dart';

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
  final _debouncer = Debouncer(duration: const Duration(milliseconds: 280));

  CancelToken? _inFlight;
  List<SearchSuggestion> _suggestions = const [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _debouncer.dispose();
    _inFlight?.cancel();
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
      final results =
          await ref.read(catalogRepositoryProvider).suggest(query, cancelToken: token);
      if (!mounted || token.isCancelled) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _suggestions = const [];
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
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: l.searchHint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
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

    if (_loading && _suggestions.isEmpty) {
      return const _SuggestSkeleton();
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

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _suggestions.length + 1,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.cs.outlineVariant),
      itemBuilder: (context, index) {
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

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion});

  final SearchSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final price = suggestion.price;

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
      subtitle: price == null
          ? null
          : Text(Fmt.price(price, locale: locale)),
      onTap: () {
        Haptics.selection();
        context.push('/product/${suggestion.id}');
      },
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.queries,
    required this.onPick,
    required this.onClear,
  });

  final List<String> queries;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    if (queries.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        title: l.searchTitle,
        message: l.searchStartHint,
        compact: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(l.searchRecent, style: context.tt.titleSmall)),
            TextButton(onPressed: onClear, child: Text(l.searchClearRecent)),
          ],
        ),
        Gap.h8,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in queries)
              ActionChip(
                avatar: Icon(Icons.history_rounded, size: 15, color: cs.onSurfaceVariant),
                label: Text(query),
                onPressed: () => onPick(query),
              ),
          ],
        ),
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
