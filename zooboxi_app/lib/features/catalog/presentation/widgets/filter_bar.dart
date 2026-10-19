import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// The bar that stays with the customer while the grid scrolls under it:
/// «فلترة» with how many picks are on, the sort, a few one-tap values the
/// store promotes for this list, and — once something is applied — a row
/// of what is applied, each removable, with «مسح الكل».
///
/// Pinned (Baymard: the filter entry point must stay reachable on a long
/// list; the applied overview is how a customer knows why the list shrank).
class FilterBarDelegate extends SliverPersistentHeaderDelegate {
  FilterBarDelegate({
    required this.query,
    required this.facets,
    required this.sortLabel,
    required this.onFilters,
    required this.onSort,
    required this.onToggle,
    required this.onClearPrice,
    required this.onClearAll,
    required this.textScaler,
    this.headerGroups = const {},
  });

  final ListingQuery query;
  final ListingFacets facets;
  final String? sortLabel;
  final VoidCallback? onFilters;
  final VoidCallback? onSort;
  final void Function(String group, String value) onToggle;
  final VoidCallback onClearPrice;
  final VoidCallback onClearAll;
  final TextScaler textScaler;

  /// Facets the page head already shows as its own rows («كل المنتجات»'s pet
  /// tabs and shelf chips) — not repeated in the applied row.
  final Set<String> headerGroups;

  static const double _main = 60;
  static const double _applied = 44;

  bool get _hasApplied => query.hasPrice || query.filters.keys.any((k) => !headerGroups.contains(k));

  double get _height => (_main + (_hasApplied ? _applied : 0)) * textScaler.clamp(maxScaleFactor: 1.15).scale(1) + 1;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = context.cs;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Material(
        color: cs.surface,
        elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: Column(
          children: [
            Expanded(child: _MainRow(delegate: this)),
            if (_hasApplied) Expanded(child: _AppliedRow(delegate: this)),
            Divider(height: 1, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(FilterBarDelegate old) =>
      old.query != query || old.facets != facets || old.sortLabel != sortLabel || old.textScaler != textScaler ||
      old.headerGroups.length != headerGroups.length ||
      (old.onFilters == null) != (onFilters == null) || (old.onSort == null) != (onSort == null);
}

class _MainRow extends StatelessWidget {
  const _MainRow({required this.delegate});

  final FilterBarDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final d = delegate;
    final promoted = d.facets.promoted;

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 8),
      children: [
        _PillButton(
          icon: Icons.tune_rounded,
          label: l.filterButton,
          badge: d.query.activeFilterCount,
          strong: true,
          onTap: d.onFilters,
        ),
        Gap.w8,
        _PillButton(
          icon: Icons.swap_vert_rounded,
          label: d.sortLabel ?? l.listingSort,
          onTap: d.onSort,
        ),
        if (promoted.isNotEmpty) ...[
          Gap.w8,
          Center(child: Container(width: 1, height: 26, color: cs.outlineVariant)),
          for (final p in promoted) ...[
            Gap.w8,
            FacetChip(
              label: p.label,
              icon: p.icon,
              selected: d.query.isSelected(p.group, p.value),
              onTap: () => d.onToggle(p.group, p.value),
            ),
          ],
        ],
      ],
    );
  }
}

class _AppliedRow extends StatelessWidget {
  const _AppliedRow({required this.delegate});

  final FilterBarDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final d = delegate;
    final locale = Localizations.localeOf(context).languageCode;
    final chips = <Widget>[];

    for (final entry in d.query.filters.entries) {
      if (d.headerGroups.contains(entry.key)) continue;
      final group = d.facets.group(entry.key);
      for (final value in entry.value) {
        chips.add(FacetChip(
          label: group?.labelOf(value) ?? value,
          selected: true,
          removable: true,
          compact: true,
          onTap: () => d.onToggle(entry.key, value),
        ));
      }
    }
    if (d.query.hasPrice) {
      chips.add(FacetChip(
        label: priceWindowLabel(l, locale, d.query.minPrice, d.query.maxPrice),
        selected: true,
        removable: true,
        compact: true,
        onTap: d.onClearPrice,
      ));
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
      children: [
        Center(
          child: Text(l.filterApplied, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        for (final chip in chips) ...[Gap.w6, chip],
        Gap.w4,
        Center(
          child: TextButton(
            onPressed: () {
              Haptics.light();
              d.onClearAll();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.isDark ? ZbTokens.coralOnDark : ZbTokens.coralDark,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l.filterClearAll, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

/// «من 5 ﷼ – 30 ﷼» / «حتى 30 ﷼» / «من 5 ﷼».
String priceWindowLabel(L l, String locale, double? min, double? max) {
  String p(double v) => Fmt.price(v, locale: locale, decimals: 0);
  if (min != null && max != null) return l.filterPriceChip(p(min), p(max));
  if (max != null) return l.filterPriceUpTo(p(max));
  return l.filterPriceFromOnly(p(min ?? 0));
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final int badge;

  /// The filter entry point: ink-filled so it is the first thing found.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final bg = strong ? cs.onSurface : cs.surface;
    final fg = strong ? cs.surface : cs.onSurface;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: strong ? BorderSide.none : BorderSide(color: cs.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  Haptics.light();
                  onTap!();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                Gap.w6,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800),
                  ),
                ),
                if (badge > 0) ...[
                  Gap.w6,
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.isDark ? ZbTokens.coralOnDark : ZbTokens.coral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      Fmt.number(badge, locale: Localizations.localeOf(context).languageCode, decimals: 0),
                      style: context.tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One facet value as a pill — a sticker, the label, and when applied a
/// teal ring (and an ✕ in the applied row).
class FacetChip extends StatelessWidget {
  const FacetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.removable = false,
    this.compact = false,
    this.count,
  });

  final String label;
  final String? icon;
  final bool selected;
  final bool removable;
  final bool compact;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dark = context.isDark;
    final accent = dark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final tint = dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint;
    final fg = selected ? (dark ? ZbTokens.tealOnDark : ZbTokens.tealDeep) : cs.onSurface;
    final hasIcon = FacetSticker.has(icon);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? tint : cs.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : cs.outlineVariant, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  Haptics.selection();
                  onTap!();
                },
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: hasIcon ? 6 : 12, end: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIcon) ...[FacetSticker(icon, size: compact ? 20 : 26), Gap.w4],
                Text(
                  label,
                  maxLines: 1,
                  style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
                if (count != null) ...[
                  Gap.w4,
                  Text(
                    Fmt.number(count!, locale: Localizations.localeOf(context).languageCode, decimals: 0),
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (removable) ...[Gap.w4, Icon(Icons.close_rounded, size: 15, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
