import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/utils/error_text.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';
import '../../../notifications/data/push_repository.dart';
import 'filter_bar.dart' show priceWindowLabel;

/// Nothing matches — and the page says exactly which tap brings results
/// back, each with its number (Baymard: 88% of mobile sites leave a dead end
/// here). Built only from what the store already counted: dropping one pick
/// (`relax`) and trading a pick for a sibling value that has products.
class FilteredEmpty extends StatelessWidget {
  const FilteredEmpty({
    super.key,
    required this.query,
    required this.facets,
    required this.onQuery,
  });

  final ListingQuery query;
  final ListingFacets facets;
  final ValueChanged<ListingQuery> onQuery;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final options = <_Option>[];
    // 1 — drop one pick, biggest return first.
    final relax = [...facets.relax.where((r) => r.count > 0)]..sort((a, b) => b.count.compareTo(a.count));
    for (final r in relax.take(2)) {
      options.add(_Option(
        label: r.group == 'price' ? l.emptyRemovePrice : l.emptyRemove(r.label),
        count: r.count,
        strong: options.isEmpty,
        icon: null,
        query: r.group == 'price' ? query.copyWith(clearPrice: true) : query.toggled(r.group, r.value),
      ));
    }
    // 2 — swap a pick for a sibling value that has products with the rest.
    for (final entry in query.filters.entries) {
      final group = facets.group(entry.key);
      if (group == null) continue;
      final alternatives = [...group.values.where((v) => v.count > 0 && !entry.value.contains(v.key))]
        ..sort((a, b) => b.count.compareTo(a.count));
      for (final alt in alternatives.take(1)) {
        options.add(_Option(
          label: l.emptySwap(alt.label),
          count: alt.count,
          strong: false,
          icon: alt.icon,
          query: query.withGroup(entry.key, {alt.key}),
        ));
      }
      if (options.length >= 4) break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        children: [
          const SizedBox(
            height: 150,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Companion(ZbPose.wow, height: 150, idle: ZbIdle.breathe),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.emptyFilteredTitle, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Gap.h4,
                Text(l.emptyFilteredBody, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                Gap.h12,
                for (final o in options) ...[
                  _OptionRow(
                    option: o,
                    onTap: () {
                      Haptics.light();
                      onQuery(o.query);
                    },
                  ),
                  Gap.h8,
                ],
                Gap.h4,
                FilledButton.tonal(
                  onPressed: () {
                    Haptics.light();
                    onQuery(query.cleared());
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(l.emptyClearAll),
                ),
                if (_picksInWords(context).isNotEmpty) ...[
                  Gap.h12,
                  Divider(height: 1, color: cs.outlineVariant),
                  Gap.h12,
                  _WatchButton(query: query, what: _picksInWords(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// «بط · قطط صغيرة · رطب» — what was asked for, in the store's words.
  String _picksInWords(BuildContext context) {
    final words = <String>[];
    for (final entry in query.filters.entries) {
      final group = facets.group(entry.key);
      for (final value in entry.value) {
        words.add(group?.labelOf(value) ?? value);
      }
    }
    if (query.hasPrice) {
      words.add(priceWindowLabel(L.of(context), Localizations.localeOf(context).languageCode, query.minPrice, query.maxPrice));
    }
    return words.join(' · ');
  }
}

/// «نبّهني إذا وصل…» — the store asks the question again every hour and
/// pushes once when something in stock, near them, answers it.
class _WatchButton extends ConsumerStatefulWidget {
  const _WatchButton({required this.query, required this.what});

  final ListingQuery query;
  final String what;

  @override
  ConsumerState<_WatchButton> createState() => _WatchButtonState();
}

class _WatchButtonState extends ConsumerState<_WatchButton> {
  bool _on = false;

  /// Only while a tap is being answered; reading the state never blocks it.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_WatchButton old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _on = false;
      _read();
    }
  }

  Future<void> _read() async {
    final asked = widget.query;
    try {
      final on = await ref.read(pushRepositoryProvider).filterWatching(asked);
      if (mounted && widget.query == asked) setState(() => _on = on);
    } catch (_) {
      // Unknown is shown as not watching; a tap asks again.
    }
  }

  Future<void> _toggle() async {
    final l = L.of(context);
    final wasOn = _on;
    Haptics.light();
    setState(() => _busy = true);
    try {
      final repository = ref.read(pushRepositoryProvider);
      final on = wasOn
          ? await repository.unwatchFilter(widget.query)
          : await repository.watchFilter(widget.query, label: widget.what);
      if (!mounted) return;
      setState(() => _on = on);
      AppToast.success(context, on ? l.emptyNotifyOn : l.emptyNotifyRemoved);
    } catch (error) {
      if (!mounted) return;
      Haptics.warning();
      AppToast.error(context, errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    if (_on) {
      return Row(
        children: [
          Icon(Icons.notifications_active_rounded, size: 20, color: context.isDark ? ZbTokens.tealOnDark : ZbTokens.tealDark),
          Gap.w8,
          Expanded(child: Text(l.emptyNotifyOn, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          TextButton(onPressed: _busy ? null : _toggle, child: Text(l.emptyNotifyCancel)),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _toggle,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: cs.onSurface,
        foregroundColor: cs.surface,
      ),
      icon: const Icon(Icons.notifications_none_rounded, size: 20),
      label: Text(l.emptyNotify(widget.what), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    );
  }
}

class _Option {
  const _Option({required this.label, required this.count, required this.strong, required this.icon, required this.query});

  final String label;
  final int count;
  final bool strong;
  final String? icon;
  final ListingQuery query;
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onTap});

  final _Option option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dark = context.isDark;
    final accent = dark ? ZbTokens.tealOnDark : ZbTokens.tealDark;
    final tint = dark ? ZbTokens.tealContainerDark : ZbTokens.tealTintSoft;
    return Material(
      color: option.strong ? tint : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        side: BorderSide(color: option.strong ? accent : cs.outlineVariant, width: option.strong ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (FacetSticker.has(option.icon))
                FacetSticker(option.icon, size: 28)
              else
                Icon(Icons.undo_rounded, size: 22, color: accent),
              Gap.w10,
              Expanded(
                child: Text(
                  option.label,
                  style: context.tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: option.strong ? accent : cs.onSurface,
                  ),
                ),
              ),
              Text(
                L.of(context).filterProductCount(option.count),
                style: context.tt.labelLarge?.copyWith(color: option.strong ? accent : cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
