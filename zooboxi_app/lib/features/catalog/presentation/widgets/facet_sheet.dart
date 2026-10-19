import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';
import '../../data/catalog_repository.dart';

/// The pane key the price window sits under in the rail.
const _kPrice = 'price';

/// «اللوحة» — the filter sheet.
///
/// Two panes, the way the owner's reference (Petzone) lays it out, with what
/// that app gets wrong fixed: the rail on the start side carries each facet's
/// sticker and how many of its values are ticked; the pane beside it lists
/// the values with counts that move as you tick (every number is what the
/// grid would show), empty values fade with the reason instead of opening an
/// empty page, and the button says the result before you press it.
///
/// Picks are staged and applied together (batch apply — Baymard/NN-g for
/// mobile), but the counts are live: each change asks the store for one
/// product of the new query and adopts its facets.
class FacetSheet extends ConsumerStatefulWidget {
  const FacetSheet({
    super.key,
    required this.query,
    required this.facets,
    required this.total,
    this.initialGroup,
  });

  final ListingQuery query;
  final ListingFacets facets;
  final int total;

  /// Opens on this facet (a promoted chip's «المزيد», say).
  final String? initialGroup;

  @override
  ConsumerState<FacetSheet> createState() => _FacetSheetState();
}

class _FacetSheetState extends ConsumerState<FacetSheet> {
  late ListingQuery _draft = widget.query;
  late ListingFacets _facets = widget.facets;
  late int _total = widget.total;
  late String _active = _firstPane();
  bool _counting = false;
  bool _failed = false;
  Timer? _debounce;
  int _generation = 0;
  final _brandSearch = TextEditingController();

  String _firstPane() {
    final wanted = widget.initialGroup;
    if (wanted != null && (wanted == _kPrice || widget.facets.group(wanted) != null)) return wanted;
    if (widget.facets.groups.isNotEmpty) return widget.facets.groups.first.key;
    return _kPrice;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _brandSearch.dispose();
    super.dispose();
  }

  /// The rail: the store's facet order, the price window after the brand.
  List<String> get _panes {
    final keys = [for (final g in _facets.groups) g.key];
    final price = _facets.price;
    if (price != null && price.isUsable || _draft.hasPrice) {
      final at = keys.indexOf('brand');
      keys.insert(at < 0 ? keys.length : at + 1, _kPrice);
    }
    return keys;
  }

  void _change(ListingQuery next) {
    Haptics.selection();
    setState(() {
      _draft = next;
      _counting = true;
      _failed = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _recount);
  }

  Future<void> _recount() async {
    final generation = ++_generation;
    try {
      final result = await ref.read(catalogRepositoryProvider).products(_draft.copyWith(perPage: 1), 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!result.facets.isEmpty) _facets = result.facets;
        _total = result.total;
        _counting = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _counting = false;
        _failed = true;
      });
    }
  }

  void _clearAll() => _change(_draft.cleared());

  /// The locked tile: pick the shelf that opens the food facets, and show it.
  void _unlock(LockedFacets locked) {
    if (!_draft.isSelected(locked.unlockGroup, locked.unlockValue)) {
      _change(_draft.toggled(locked.unlockGroup, locked.unlockValue));
    }
    if (_facets.group(locked.unlockGroup) != null) setState(() => _active = locked.unlockGroup);
  }

  void _apply() {
    Haptics.light();
    Navigator.of(context).pop(_draft);
  }

  int _selectedIn(String pane) =>
      pane == _kPrice ? (_draft.hasPrice ? 1 : 0) : (_draft.filters[pane]?.length ?? 0);

  String _summary(L l) {
    final parts = <String>[];
    for (final g in _facets.groups) {
      for (final v in _draft.filters[g.key] ?? const <String>{}) {
        parts.add(g.labelOf(v) ?? v);
      }
    }
    return parts.isEmpty ? l.filterNoneSelected : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final panes = _panes;
    final active = panes.contains(_active) ? _active : (panes.isEmpty ? _kPrice : panes.first);
    final height = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: l.filterSheetTitle,
                summary: _summary(l),
                onClose: () => Navigator.of(context).pop(),
                onClear: _draft.hasFilters ? _clearAll : null,
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rail(
                      panes: panes,
                      active: active,
                      facets: _facets,
                      selectedIn: _selectedIn,
                      onSelect: (key) {
                        Haptics.selection();
                        setState(() => _active = key);
                      },
                      onUnlock: _unlock,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: context.motion(Motion.select),
                        child: KeyedSubtree(
                          key: ValueKey(active),
                          child: active == _kPrice
                              ? _PricePane(
                                  facet: _facets.price,
                                  query: _draft,
                                  onChanged: _change,
                                )
                              : _ValuesPane(
                                  group: _facets.group(active)!,
                                  query: _draft,
                                  search: _brandSearch,
                                  onToggle: (value) => _change(_draft.toggled(active, value)),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(
                total: _total,
                counting: _counting,
                failed: _failed,
                onCancel: () => Navigator.of(context).pop(),
                onApply: _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.summary, required this.onClose, this.onClear});

  final String title;
  final String summary;
  final VoidCallback onClose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 8, 10),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(backgroundColor: cs.surfaceContainerHigh, foregroundColor: cs.onSurface),
          ),
          Gap.w8,
          Expanded(
            child: Column(
              children: [
                Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Gap.w8,
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: context.isDark ? ZbTokens.coralOnDark : ZbTokens.coralDark),
            child: Text(l.filterClearAll, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.panes,
    required this.active,
    required this.facets,
    required this.selectedIn,
    required this.onSelect,
    required this.onUnlock,
  });

  final List<String> panes;
  final String active;
  final ListingFacets facets;
  final int Function(String pane) selectedIn;
  final ValueChanged<String> onSelect;
  final ValueChanged<LockedFacets> onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return Container(
      width: 100,
      color: cs.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final pane in panes)
            _RailItem(
              label: pane == _kPrice ? l.filterPrice : (facets.group(pane)?.label ?? pane),
              icon: pane == _kPrice ? 'price' : facets.group(pane)?.icon,
              active: pane == active,
              selected: selectedIn(pane),
              onTap: () => onSelect(pane),
            ),
          if (facets.locked != null) _LockedTile(locked: facets.locked!, onTap: () => onUnlock(facets.locked!)),
        ],
      ),
    );
  }

}

/// «العمر · النكهة · القوام — تظهر عند اختيار الطعام»: the food facets the
/// store holds back on a mixed list. A tap picks the food shelf.
class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.locked, required this.onTap});

  final LockedFacets locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.45), width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(height: 4),
                  Text(
                    locked.label,
                    textAlign: TextAlign.center,
                    style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locked.hint,
                    textAlign: TextAlign.center,
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8), height: 1.35, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? icon;
  final bool active;
  final int selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = context.isDark ? ZbTokens.tealOnDark : ZbTokens.teal;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? cs.surface : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (active)
                PositionedDirectional(
                  start: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(3)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: FacetSticker(icon, size: 30, dimmed: !active && selected == 0)),
                    Gap.h4,
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelMedium?.copyWith(
                        color: active ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected > 0)
                PositionedDirectional(
                  top: 6,
                  end: 10,
                  child: _CountBadge(count: selected),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.isDark ? ZbTokens.coralOnDark : ZbTokens.coral,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          Fmt.number(count, locale: Localizations.localeOf(context).languageCode, decimals: 0),
          style: context.tt.labelSmall?.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1),
        ),
      );
}

class _PaneTitle extends StatelessWidget {
  const _PaneTitle({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(hint, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
        ),
      );
}

class _ValuesPane extends StatefulWidget {
  const _ValuesPane({
    required this.group,
    required this.query,
    required this.search,
    required this.onToggle,
  });

  final FacetGroup group;
  final ListingQuery query;
  final TextEditingController search;
  final ValueChanged<String> onToggle;

  @override
  State<_ValuesPane> createState() => _ValuesPaneState();
}

class _ValuesPaneState extends State<_ValuesPane> {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final group = widget.group;
    final needle = widget.search.text.trim().toLowerCase();
    final withIcons = group.values.any((v) => FacetSticker.has(v.icon));

    // Live values first, the faded ones after them — but a fixed vocabulary
    // (kitten → adult → senior) keeps its own order among the live ones.
    final live = <FacetValue>[];
    final dead = <FacetValue>[];
    for (final v in group.values) {
      if (needle.isNotEmpty && !v.label.toLowerCase().contains(needle)) continue;
      final selected = widget.query.isSelected(group.key, v.key);
      (v.isEmpty && !selected ? dead : live).add(v);
    }

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
      children: [
        _PaneTitle(title: group.label, hint: l.filterLiveHint),
        if (group.searchable) ...[
          Gap.h4,
          TextField(
            controller: widget.search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l.filterBrandSearch,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          ),
          Gap.h4,
        ],
        for (final v in live)
          _ValueRow(
            value: v,
            showIcon: withIcons,
            selected: widget.query.isSelected(group.key, v.key),
            onTap: () => widget.onToggle(v.key),
          ),
        for (final v in dead)
          _ValueRow(value: v, showIcon: withIcons, selected: false, onTap: null),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value, required this.showIcon, required this.selected, required this.onTap});

  final FacetValue value;
  final bool showIcon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dim = onTap == null;
    final accent = context.isDark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final locale = Localizations.localeOf(context).languageCode;
    final second = dim ? (value.note ?? value.sub) : value.sub;
    final ink = dim ? cs.onSurfaceVariant.withValues(alpha: 0.6) : cs.onSurface;

    return Semantics(
      checked: selected,
      enabled: !dim,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZbTokens.rSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)))),
          child: Row(
            children: [
              AnimatedContainer(
                duration: context.motion(Motion.select),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: selected ? accent : cs.outline.withValues(alpha: dim ? 0.3 : 0.7), width: 2),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
              ),
              Gap.w10,
              if (showIcon) ...[
                FacetSticker(value.icon, size: 30, dimmed: dim),
                Gap.w8,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.label,
                      style: context.tt.bodyLarge?.copyWith(
                        color: ink,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (second != null && second.isNotEmpty)
                      Text(
                        second,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: dim ? 0.7 : 1), height: 1.3),
                      ),
                  ],
                ),
              ),
              Gap.w8,
              Text(
                Fmt.number(value.count, locale: locale, decimals: 0),
                style: context.tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: dim ? 0.5 : 1),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The price of THIS list: its own histogram over the slider, from/to
/// readouts, and four ready windows at its quartiles.
class _PricePane extends StatefulWidget {
  const _PricePane({required this.facet, required this.query, required this.onChanged});

  final PriceFacet? facet;
  final ListingQuery query;
  final ValueChanged<ListingQuery> onChanged;

  @override
  State<_PricePane> createState() => _PricePaneState();
}

class _PricePaneState extends State<_PricePane> {
  RangeValues? _drag;

  RangeValues _value(PriceFacet f) {
    final lo = (widget.query.minPrice ?? f.min).clamp(f.min, f.max).toDouble();
    final hi = (widget.query.maxPrice ?? f.max).clamp(f.min, f.max).toDouble();
    return RangeValues(lo, hi < lo ? lo : hi);
  }

  void _commit(PriceFacet f, RangeValues v) {
    final lo = v.start <= f.min + 0.5 ? null : v.start.floorToDouble();
    final hi = v.end >= f.max - 0.5 ? null : v.end.ceilToDouble();
    setState(() => _drag = null);
    widget.onChanged(lo == null && hi == null
        ? widget.query.copyWith(clearPrice: true)
        : ListingQuery(
            category: widget.query.category,
            brand: widget.query.brand,
            q: widget.query.q,
            sku: widget.query.sku,
            rail: widget.query.rail,
            filters: widget.query.filters,
            minPrice: lo,
            maxPrice: hi,
            orderBy: widget.query.orderBy,
            perPage: widget.query.perPage,
          ));
  }

  bool _isBucket(PriceBucket b) => widget.query.minPrice == b.min && widget.query.maxPrice == b.max && widget.query.hasPrice;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final f = widget.facet;
    final accent = context.isDark ? ZbTokens.tealOnDark : ZbTokens.teal;

    if (f == null || !f.isUsable) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
        children: [
          _PaneTitle(title: l.filterPrice, hint: l.filterPriceHint),
          if (widget.query.hasPrice)
            OutlinedButton(
              onPressed: () => widget.onChanged(widget.query.copyWith(clearPrice: true)),
              child: Text(l.emptyRemovePrice),
            ),
        ],
      );
    }

    final value = _drag ?? _value(f);
    String price(double v) => Fmt.price(v, locale: locale, decimals: 0);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
      children: [
        _PaneTitle(title: l.filterPrice, hint: l.filterPriceHint),
        Gap.h12,
        // A price axis reads low → high left to right in every script.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CustomPaint(
                    painter: _HistogramPainter(
                      bins: f.histogram,
                      from: value.start,
                      to: value.end,
                      on: accent,
                      off: accent.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
              RangeSlider(
                values: value,
                min: f.min,
                max: f.max,
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) => _commit(f, v),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _Readout(label: l.filterPriceFrom, value: price(value.start))),
            Gap.w8,
            Expanded(child: _Readout(label: l.filterPriceTo, value: price(value.end))),
          ],
        ),
        if (f.buckets.isNotEmpty) ...[
          Gap.h16,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in f.buckets)
                ChoiceChip(
                  selected: _isBucket(b),
                  showCheckmark: false,
                  onSelected: b.count == 0 && !_isBucket(b)
                      ? null
                      : (_) {
                          if (_isBucket(b)) {
                            widget.onChanged(widget.query.copyWith(clearPrice: true));
                          } else {
                            widget.onChanged(ListingQuery(
                              category: widget.query.category,
                              brand: widget.query.brand,
                              q: widget.query.q,
                              sku: widget.query.sku,
                              rail: widget.query.rail,
                              filters: widget.query.filters,
                              minPrice: b.min,
                              maxPrice: b.max,
                              orderBy: widget.query.orderBy,
                              perPage: widget.query.perPage,
                            ));
                          }
                        },
                  label: Text.rich(TextSpan(children: [
                    TextSpan(text: b.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                      text: '  ${Fmt.number(b.count, locale: locale, decimals: 0)}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ])),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(ZbTokens.rSm),
      ),
      child: Row(
        children: [
          Text(label, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({required this.bins, required this.from, required this.to, required this.on, required this.off});

  final List<PriceBin> bins;
  final double from;
  final double to;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;
    final peak = bins.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    if (peak == 0) return;
    const gap = 3.0;
    final w = (size.width - gap * (bins.length - 1)) / bins.length;
    for (var i = 0; i < bins.length; i++) {
      final b = bins[i];
      final h = b.count == 0 ? 2.0 : 6 + (size.height - 6) * b.count / peak;
      final inside = b.to > from && b.from < to;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(i * (w + gap), size.height - h, w, h),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = inside ? on : off);
    }
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.bins != bins || old.from != from || old.to != to || old.on != on;
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.counting,
    required this.failed,
    required this.onCancel,
    required this.onApply,
  });

  final int total;
  final bool counting;
  final bool failed;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final none = !counting && !failed && total == 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 18)),
              child: Text(l.actionCancel),
            ),
            Gap.w10,
            Expanded(
              child: FilledButton(
                onPressed: none ? null : onApply,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                child: AnimatedSwitcher(
                  duration: context.motion(Motion.select),
                  child: counting
                      ? const SizedBox(
                          key: ValueKey('busy'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          none ? l.filterNoResults : l.filterShowResults(total),
                          key: ValueKey('n$total$none'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
