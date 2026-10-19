import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';
import '../../data/catalog_repository.dart';
import '../pet_palette.dart';

/// «كل المنتجات» — «الممرّ» over the whole store: which pet first (a tab per
/// pet, drawn by the cast, with how many products each has here), then which
/// shelf (a chip per department, biggest first for that pet). Both are the
/// store's own facets (`species`, `dept`), so every number moves with the
/// other picks and a tap is the same pick the filter sheet would make.
class AllProductsHead extends StatelessWidget {
  const AllProductsHead({
    super.key,
    required this.query,
    required this.facets,
    required this.onQuery,
  });

  final ListingQuery query;
  final ListingFacets facets;
  final ValueChanged<ListingQuery> onQuery;

  /// The store's pets in the order the categories screen paints them.
  static const pets = ['cat', 'dog', 'bird', 'small'];

  static const _petSticker = {'cat': 'cat_adult', 'dog': 'dog_adult', 'bird': 'bird', 'small': 'small'};

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final species = facets.group('species');
    final shelves = facets.group('dept');
    if (species == null && shelves == null) return const SizedBox.shrink();

    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (species != null) _PetTabs(group: species, query: query, facets: facets, onQuery: onQuery),
          if (shelves != null) _ShelfRow(group: shelves, query: query, onQuery: onQuery),
        ],
      ),
    );
  }
}

class _PetTabs extends StatelessWidget {
  const _PetTabs({required this.group, required this.query, required this.facets, required this.onQuery});

  final FacetGroup group;
  final ListingQuery query;
  final ListingFacets facets;
  final ValueChanged<ListingQuery> onQuery;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final picked = query.filters['species'] ?? const <String>{};
    final byKey = {for (final v in group.values) v.key: v};
    // «الكل» counts the store only while nothing else narrows it.
    final othersPicked = query.hasPrice || query.filters.keys.any((k) => k != 'species');

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: _PetTab(
              label: l.allProductsEveryPet,
              sticker: 'all',
              count: othersPicked ? null : facets.baseTotal,
              selected: picked.isEmpty,
              palette: null,
              onTap: () => onQuery(query.withGroup('species', const {})),
            ),
          ),
          for (final (index, key) in AllProductsHead.pets.indexed)
            if (byKey[key] != null)
              Expanded(
                child: _PetTab(
                  label: _short(l, byKey[key]!),
                  sticker: AllProductsHead._petSticker[key],
                  count: byKey[key]!.count,
                  selected: picked.length == 1 && picked.contains(key),
                  palette: PetPalette.resolve(context, index: index),
                  onTap: () => onQuery(query.withGroup('species', {key})),
                ),
              ),
        ],
      ),
    );
  }

  /// «حيوانات صغيرة» does not fit a fifth of a phone; the store sends «صغيرة».
  String _short(L l, FacetValue v) => v.short ?? v.label;
}

class _PetTab extends StatelessWidget {
  const _PetTab({
    required this.label,
    required this.sticker,
    required this.count,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String? sticker;
  final int? count;
  final bool selected;
  final PetPalette? palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = palette?.accent ?? cs.onSurface;
    final well = selected ? (palette?.chipFill(context) ?? cs.surfaceContainerHighest) : cs.surfaceContainerLow;
    final locale = Localizations.localeOf(context).languageCode;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: selected
            ? null
            : () {
                Haptics.selection();
                onTap();
              },
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: well,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
                ),
                child: FacetSticker(sticker, size: 36),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 16,
                child: count == null
                    ? null
                    : Text(
                        Fmt.number(count!, locale: locale, decimals: 0),
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shelves, one tap each: a chip picks that shelf alone (the sheet is
/// where several are combined), a tap on the picked one lets it go.
class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.group, required this.query, required this.onQuery});

  final FacetGroup group;
  final ListingQuery query;
  final ValueChanged<ListingQuery> onQuery;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final picked = query.filters['dept'] ?? const <String>{};
    final shown = [for (final v in group.values) if (v.count > 0 || picked.contains(v.key)) v];

    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          _ShelfChip(
            label: l.allProductsEveryShelf,
            sticker: null,
            count: null,
            selected: picked.isEmpty,
            onTap: () => onQuery(query.withGroup('dept', const {})),
          ),
          for (final v in shown) ...[
            Gap.w8,
            _ShelfChip(
              label: v.short ?? v.label,
              sticker: v.icon,
              count: v.count,
              selected: picked.length == 1 && picked.contains(v.key),
              onTap: () => onQuery(query.withGroup('dept', picked.length == 1 && picked.contains(v.key) ? const {} : {v.key})),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelfChip extends StatelessWidget {
  const _ShelfChip({
    required this.label,
    required this.sticker,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? sticker;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dark = context.isDark;
    final accent = dark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final tint = dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint;
    final fg = selected ? (dark ? ZbTokens.tealOnDark : ZbTokens.tealDeep) : cs.onSurface;
    final hasSticker = FacetSticker.has(sticker);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? tint : cs.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : cs.outlineVariant, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: hasSticker ? 6 : 14, end: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSticker) ...[FacetSticker(sticker, size: 26), Gap.w4],
                Text(label, maxLines: 1, style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (count != null) ...[
                  Gap.w4,
                  Text(
                    Fmt.number(count!, locale: Localizations.localeOf(context).languageCode, decimals: 0),
                    style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

/// The way in: «كل المنتجات» at the top of the categories tab — the store's
/// size and each pet's share, one tap to the whole store with its filters.
class AllProductsCard extends ConsumerWidget {
  const AllProductsCard({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    final accent = dark ? ZbTokens.tealOnDark : ZbTokens.teal;
    final tint = dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint;
    final locale = Localizations.localeOf(context).languageCode;
    final summary = ref.watch(listingFirstPageProvider(const ListingQuery(perPage: 1))).value;
    final species = summary?.facets.group('species');
    final byKey = {for (final v in species?.values ?? const <FacetValue>[]) v.key: v};

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        side: BorderSide(color: accent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.light();
          onOpen();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(ZbTokens.rMd)),
                child: const FacetSticker('all', size: 44),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.allProductsTitle, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      summary == null ? l.allProductsCardHint : '${l.filterProductCount(summary.facets.baseTotal)} · ${l.allProductsCardHint}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (byKey.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final (index, key) in AllProductsHead.pets.indexed)
                            if (byKey[key] != null && byKey[key]!.count > 0)
                              Container(
                                height: 26,
                                padding: const EdgeInsetsDirectional.only(start: 2, end: 8),
                                decoration: BoxDecoration(
                                  color: PetPalette.resolve(context, index: index).chipFill(context),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FacetSticker(AllProductsHead._petSticker[key], size: 22),
                                    Gap.w4,
                                    Text(
                                      Fmt.number(byKey[key]!.count, locale: locale, decimals: 0),
                                      style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Gap.w8,
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(
                  context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: dark ? ZbTokens.graphite : Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
