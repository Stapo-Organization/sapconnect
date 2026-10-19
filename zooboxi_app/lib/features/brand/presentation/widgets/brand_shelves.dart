import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/facet_sticker.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/price_text.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'brand_palette.dart';

/// «خطوط إينابا»: the brand's own product lines as picture tiles — Churu,
/// Dashi Delights… — or, for a brand without curated lines, the split the
/// store's facet index finds best (its pets, its food types, its needs).
/// A tile is a filter: the grid below narrows in place and the tile rings.
class BrandShelvesRail extends StatelessWidget {
  const BrandShelvesRail({
    super.key,
    required this.page,
    required this.palette,
    required this.isSelected,
    required this.onSelect,
  });

  final BrandPage page;
  final BrandPalette palette;
  final bool Function(BrandShelf shelf) isSelected;
  final ValueChanged<BrandShelf> onSelect;

  static const double _width = 148;
  static const double _height = 164;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final shelves = page.shelvesToShow;
    if (shelves.length < 2) return const SizedBox.shrink();
    final lines = identical(shelves, page.lines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
          child: Text(
            lines ? l.brandLinesTitle(page.name) : l.brandShelvesTitle(page.name),
            style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: shelves.length,
            separatorBuilder: (_, _) => Gap.w10,
            itemBuilder: (context, i) => _ShelfTile(
              shelf: shelves[i],
              palette: palette,
              selected: isSelected(shelves[i]),
              onTap: () => onSelect(shelves[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.shelf, required this.palette, required this.selected, required this.onTap});

  final BrandShelf shelf;
  final BrandPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Semantics(
      button: true,
      selected: selected,
      label: shelf.name,
      child: PressScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: context.motion(Motion.select),
          curve: Motion.decelerate,
          width: BrandShelvesRail._width,
          height: BrandShelvesRail._height,
          decoration: BoxDecoration(
            color: palette.wash,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? palette.deep : palette.tint,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              PositionedDirectional(
                end: -22,
                bottom: -40,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.tint),
                ),
              ),
              PositionedDirectional(
                end: 12,
                bottom: 10,
                width: 104,
                height: 90,
                child: shelf.image != null
                    ? ZbImage(url: shelf.image, fit: BoxFit.contain, backgroundColor: Colors.transparent)
                    : Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        child: FacetSticker.has(shelf.icon)
                            ? FacetSticker(shelf.icon!, size: 64)
                            : Icon(Icons.pets_rounded, size: 44, color: palette.deep),
                      ),
              ),
              PositionedDirectional(
                start: 12,
                top: 12,
                end: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      l.brandProductCount(shelf.count),
                      style: context.tt.labelSmall?.copyWith(
                        color: selected ? palette.deep : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                PositionedDirectional(
                  start: 10,
                  bottom: 10,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: palette.deep),
                    child: Icon(Icons.check_rounded, size: 16, color: cs.surface),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «العبوة الكبيرة أوفر»: the brand's bigger pack against its smallest of
/// the same kind, computed by the store from today's prices — per piece when
/// both are multipacks of the same weight, per kilo otherwise.
class BrandValueBand extends StatelessWidget {
  const BrandValueBand({super.key, required this.value, required this.palette});

  final BrandValue value;
  final BrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final unit = value.perUnit ? l.brandValueEachUnit : l.brandValueEachKg;
    final muted = Colors.white.withValues(alpha: 0.72);
    final product = value.product;

    return PressScale(
      onTap: () => unawaited(context.push('/product/${product.id}', extra: product)),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(color: palette.band, borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 12, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l.brandValueKicker,
                          style: context.tt.labelLarge?.copyWith(color: palette.bandInk, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Gap.w8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.bandInk,
                          borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        ),
                        child: Text(
                          l.brandValueSave(value.saving),
                          style: context.tt.labelSmall?.copyWith(color: palette.band, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ValueRow(
                    label: value.bigLabel,
                    each: value.bigEach,
                    unit: unit,
                    color: Colors.white,
                    strong: true,
                  ),
                  const SizedBox(height: 6),
                  _ValueRow(label: value.smallLabel, each: value.smallEach, unit: unit, color: muted),
                ],
              ),
            ),
            Gap.w10,
            SizedBox(
              width: 86,
              height: 96,
              child: ZbImage(url: product.image, fit: BoxFit.contain, backgroundColor: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.each, required this.unit, required this.color, this.strong = false});

  final String label;
  final double each;
  final String unit;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = (strong ? context.tt.titleMedium : context.tt.bodyMedium)?.copyWith(
      color: color,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        PriceText(price: each, style: style, color: color),
        Gap.w4,
        Text(unit, style: context.tt.labelSmall?.copyWith(color: color.withValues(alpha: 0.8))),
      ],
    );
  }
}
