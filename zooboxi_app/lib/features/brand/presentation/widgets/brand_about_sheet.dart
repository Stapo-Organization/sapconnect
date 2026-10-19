import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'brand_palette.dart';

/// «عن إينابا» (from «الملف», the owner's pick for the brand's story): the cat
/// — or the dog, for a dog brand — holds the brand's logo up on its sign in
/// front of an arch in the brand's colour; then who the brand is made for,
/// its facts, its character, and a short timeline from its founding to what
/// Zooboxi carries of it today.
class BrandAboutSheet extends StatelessWidget {
  const BrandAboutSheet({super.key, required this.page, required this.palette, required this.onShopAll});

  final BrandPage page;
  final BrandPalette palette;
  final VoidCallback onShopAll;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final holder = page.species == 'dog' ? ZbCast.dog : ZbCast.cat;
    final total = page.shelfTotal > 0 ? page.shelfTotal : page.productCount;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  // The arch and the animal holding the logo.
                  SizedBox(
                    height: 250,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 250,
                          height: 230,
                          decoration: BoxDecoration(
                            color: palette.field,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(125),
                              bottom: Radius.circular(24),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(height: 46, color: palette.stripe),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          child: SignHolder.showing(
                            cast: holder,
                            height: 220,
                            board: page.brand.logo == null
                                ? FittedBox(
                                    child: Text(
                                      page.name,
                                      style: const TextStyle(color: Color(0xFF5A2C2F), fontWeight: FontWeight.w900),
                                    ),
                                  )
                                : ZbImage(url: page.brand.logo, fit: BoxFit.contain, backgroundColor: Colors.transparent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h16,
                  Text(
                    page.name,
                    textAlign: TextAlign.center,
                    style: context.tt.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if ((page.tagline ?? '').isNotEmpty) ...[
                    Gap.h4,
                    Text(
                      page.tagline!,
                      textAlign: TextAlign.center,
                      style: context.tt.titleSmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                  Gap.h20,

                  // The passport: four facts in a grid.
                  _Passport(
                    palette: palette,
                    cells: [
                      if ((page.country ?? '').isNotEmpty) (Icons.public_rounded, l.brandFactOrigin, page.country!),
                      if ((page.founded ?? '').isNotEmpty) (Icons.flag_rounded, l.brandFactFounded, page.founded!),
                      if ((page.specialty ?? '').isNotEmpty) (Icons.pets_rounded, l.brandFactSpecialty, page.specialty!),
                      if (total > 0) (Icons.inventory_2_rounded, l.brandFactProducts, l.brandProductCount(total)),
                    ],
                  ),

                  if ((page.lead ?? '').isNotEmpty) ...[
                    Gap.h24,
                    Text(
                      l.brandAboutMadeFor,
                      style: context.tt.labelLarge?.copyWith(color: palette.deep, fontWeight: FontWeight.w800),
                    ),
                    Gap.h8,
                    Text(
                      page.lead!,
                      style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.7),
                    ),
                  ],

                  if (page.mood.isNotEmpty) ...[
                    Gap.h20,
                    Text(
                      l.brandMoodTitle,
                      style: context.tt.labelLarge?.copyWith(color: palette.deep, fontWeight: FontWeight.w800),
                    ),
                    Gap.h8,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final word in page.mood)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.wash,
                              borderRadius: BorderRadius.circular(ZbTokens.rPill),
                              border: Border.all(color: palette.tint),
                            ),
                            child: Text(
                              word,
                              style: context.tt.labelLarge?.copyWith(color: palette.deep, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ],

                  if ((page.founded ?? '').isNotEmpty && total > 0) ...[
                    Gap.h24,
                    Text(
                      l.brandAboutStory,
                      style: context.tt.labelLarge?.copyWith(color: palette.deep, fontWeight: FontWeight.w800),
                    ),
                    Gap.h12,
                    _Timeline(
                      palette: palette,
                      steps: [
                        (page.founded!, l.brandAboutFounded(page.name)),
                        (
                          l.brandAboutToday,
                          page.inStock > 0
                              ? '${l.brandProductCount(total)} · ${l.brandInStock(page.inStock)}'
                              : l.brandProductCount(total),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                onPressed: onShopAll,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.band,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                child: Text(l.brandShopAllCta(page.name)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Passport extends StatelessWidget {
  const _Passport({required this.palette, required this.cells});

  final BrandPalette palette;
  final List<(IconData, String, String)> cells;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    if (cells.isEmpty) return const SizedBox.shrink();

    Widget cell((IconData, String, String) c) => Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: palette.wash, borderRadius: BorderRadius.circular(12)),
              child: Icon(c.$1, size: 19, color: palette.deep),
            ),
            Gap.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.$2, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(
                    c.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        );

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: cell(cells[i])),
          Gap.w10,
          Expanded(child: i + 1 < cells.length ? cell(cells[i + 1]) : const SizedBox.shrink()),
        ],
      ));
      if (i + 2 < cells.length) rows.add(Gap.h12);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: rows),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.palette, required this.steps});

  final BrandPalette palette;
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    steps[i].$1,
                    style: context.tt.titleSmall?.copyWith(color: palette.deep, fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == steps.length - 1 ? palette.field : cs.surface,
                          border: Border.all(color: palette.field, width: 3),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(child: Container(width: 2, color: palette.tint)),
                    ],
                  ),
                ),
                Gap.w10,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(steps[i].$2, style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.5)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
