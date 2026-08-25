import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// The filter sheet: attribute chips plus a price range.
///
/// Selections are staged locally and only returned on "apply", so a customer
/// can explore combinations without the grid refetching under each tap.
class FacetSheet extends StatefulWidget {
  const FacetSheet({
    super.key,
    required this.query,
    required this.facets,
    this.priceBounds,
  });

  final ListingQuery query;
  final List<FacetGroup> facets;
  final PriceFacet? priceBounds;

  @override
  State<FacetSheet> createState() => _FacetSheetState();
}

class _FacetSheetState extends State<FacetSheet> {
  late Map<String, Set<String>> _selected = {
    for (final entry in widget.query.attributes.entries) entry.key: entry.value.toSet(),
  };

  RangeValues? _price;

  @override
  void initState() {
    super.initState();
    final bounds = widget.priceBounds;
    if (bounds != null && bounds.isUsable) {
      _price = RangeValues(
        (widget.query.minPrice ?? bounds.min).clamp(bounds.min, bounds.max),
        (widget.query.maxPrice ?? bounds.max).clamp(bounds.min, bounds.max),
      );
    }
  }

  int get _activeCount =>
      _selected.values.fold<int>(0, (sum, terms) => sum + terms.length) +
      (_priceChanged ? 1 : 0);

  bool get _priceChanged {
    final bounds = widget.priceBounds;
    final price = _price;
    if (bounds == null || price == null) return false;
    return price.start > bounds.min || price.end < bounds.max;
  }

  void _toggle(String taxonomy, String slug) {
    Haptics.selection();
    setState(() {
      final terms = _selected[taxonomy]?.toSet() ?? <String>{};
      if (!terms.remove(slug)) terms.add(slug);
      if (terms.isEmpty) {
        _selected.remove(taxonomy);
      } else {
        _selected[taxonomy] = terms;
      }
    });
  }

  void _clear() {
    Haptics.light();
    setState(() {
      _selected = {};
      final bounds = widget.priceBounds;
      _price = bounds == null || !bounds.isUsable
          ? null
          : RangeValues(bounds.min, bounds.max);
    });
  }

  void _apply() {
    Haptics.light();
    Navigator.of(context).pop(
      widget.query.copyWith(
        attributes: _selected,
        minPrice: _priceChanged ? _price!.start : null,
        maxPrice: _priceChanged ? _price!.end : null,
        clearPrice: !_priceChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bounds = widget.priceBounds;

    return BottomSheetScaffold(
      title: l.listingFiltersTitle,
      trailing: _activeCount == 0
          ? null
          : TextButton(onPressed: _clear, child: Text(l.actionClear)),
      footer: FilledButton(
        onPressed: _apply,
        child: Text(_activeCount == 0 ? l.actionApply : '${l.actionApply} ($_activeCount)'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bounds != null && bounds.isUsable && _price != null) ...[
            _PriceRange(
              bounds: bounds,
              value: _price!,
              onChanged: (value) => setState(() => _price = value),
            ),
            Gap.h8,
          ],
          for (final group in widget.facets) ...[
            _FacetGroupView(
              group: group,
              selected: _selected[group.taxonomy] ?? const {},
              onToggle: (slug) => _toggle(group.taxonomy, slug),
            ),
            Gap.h16,
          ],
          Gap.h8,
        ],
      ),
    );
  }
}

class _PriceRange extends StatelessWidget {
  const _PriceRange({required this.bounds, required this.value, required this.onChanged});

  final PriceFacet bounds;
  final RangeValues value;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.listingPriceRange, style: context.tt.titleSmall),
        Gap.h4,
        Text(
          '${Fmt.price(value.start, locale: locale, decimals: 0)}  –  '
          '${Fmt.price(value.end, locale: locale, decimals: 0)}',
          // A numeric range always reads low→high, regardless of script.
          textDirection: TextDirection.ltr,
          style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
        ),
        RangeSlider(
          values: value,
          min: bounds.min,
          max: bounds.max,
          divisions: 40,
          labels: RangeLabels(
            Fmt.number(value.start, locale: locale, decimals: 0),
            Fmt.number(value.end, locale: locale, decimals: 0),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FacetGroupView extends StatelessWidget {
  const _FacetGroupView({
    required this.group,
    required this.selected,
    required this.onToggle,
  });

  final FacetGroup group;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (group.terms.isEmpty) return const SizedBox.shrink();
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.label, style: context.tt.titleSmall),
        Gap.h8,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in group.terms)
              FilterChip(
                selected: selected.contains(term.slug),
                onSelected: (_) => onToggle(term.slug),
                label: Text(
                  term.count > 0 ? '${term.name} (${term.count})' : term.name,
                ),
                selectedColor: cs.primaryContainer,
                labelStyle: context.tt.labelMedium?.copyWith(
                  color: selected.contains(term.slug)
                      ? cs.onPrimaryContainer
                      : cs.onSurface,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
