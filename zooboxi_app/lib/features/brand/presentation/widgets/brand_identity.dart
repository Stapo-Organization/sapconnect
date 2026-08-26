import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

// The brand page's identity layer: the stage the name sits on, and the block
// that carries it.
//
// The hard constraint here is that **almost every brand is still bare**. The
// AI boutique kit — hero art, tagline, story, tiles — is synced brand by brand,
// so today the honest payload is a name, a logo, a handful of categories and a
// product count. Everything below therefore treats the rich fields as bonus:
// nothing is a placeholder, nothing is an empty frame waiting to be filled, and
// a brand with a name and a logo still gets a page that looks designed.

/// Puts [color] at an exact lightness, keeping its hue. Used to derive a deep
/// stage from a brand accent that was drawn for print, not for a backdrop.
Color _atLightness(Color color, double lightness) =>
    HSLColor.fromColor(color).withLightness(lightness.clamp(0.0, 1.0)).toColor();

/// The brand's own color, resolved to something that can legibly carry text and
/// chip tints **in the current theme**.
///
/// A kit accent is chosen for a logo on white; used raw it either disappears
/// into a dark surface or glares on a light one. So it is pulled into a
/// readable lightness band, and a brand with no accent simply borrows the
/// storefront's own primary rather than being tinted at random.
Color brandAccent(BuildContext context, BrandPage page) {
  final base = hexColor(page.brand.accent);

  if (context.isDark) {
    final onDark = hexColor(page.accentDark) ?? base;
    if (onDark == null) return context.cs.primary;
    final hsl = HSLColor.fromColor(onDark);
    return hsl.lightness >= 0.58 ? onDark : _atLightness(onDark, 0.66);
  }

  if (base == null) return context.cs.primary;
  final hsl = HSLColor.fromColor(base);
  return hsl.lightness <= 0.52 ? base : _atLightness(base, 0.42);
}

/// The deep gradient the hero paints. Dark mode prefers the kit's own
/// `accent_dark`; with none, the accent is darkened rather than inverted, so
/// the brand still recognises its color at the top of its page.
LinearGradient brandStage(BuildContext context, BrandPage page) {
  final base = hexColor(page.brand.accent) ?? ZbTokens.teal;

  if (context.isDark) {
    final deep = hexColor(page.accentDark) ?? _atLightness(base, 0.15);
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [deep, ZbTokens.graphiteHigh],
    );
  }

  return LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [_atLightness(base, 0.20), _atLightness(base, 0.40)],
  );
}

/// The stage behind the app bar: the brand gradient, its quiet decor, the AI
/// hero photo when one exists, and a scrim that keeps the status-bar controls
/// and the identity tile readable over any of it.
///
/// The gradient is painted **even when there is artwork**, so a hero that
/// doesn't fill the frame letterboxes into the brand's own color instead of
/// into a hole.
class BrandStage extends StatelessWidget {
  const BrandStage({super.key, required this.page});

  final BrandPage page;

  @override
  Widget build(BuildContext context) {
    final hero = page.hero;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: brandStage(context, page))),
        if (hero == null)
          const _StageDecor()
        else
          ZbImage(url: hero, fit: BoxFit.cover, backgroundColor: Colors.transparent),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: hero == null ? 0.14 : 0.32),
                Colors.transparent,
                Colors.black.withValues(alpha: hero == null ? 0.20 : 0.42),
              ],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// One quiet layer of depth on a bare stage: a big off-canvas ring and three
/// bright specks — the same restraint the home hero uses, drawn here rather
/// than imported so the two can evolve apart.
class _StageDecor extends StatelessWidget {
  const _StageDecor();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final ring = height * 1.5;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              end: -ring * 0.30,
              top: -ring * 0.40,
              child: Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1.6,
                  ),
                ),
              ),
            ),
            for (final (dx, dy, size) in const [
              (0.30, 0.24, 5.0),
              (0.46, 0.66, 3.5),
              (0.62, 0.38, 4.0),
            ])
              PositionedDirectional(
                start: width * dx,
                top: height * dy,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Logo tile + name + tagline, then the facts worth stating and the story.
///
/// It laps up onto the stage: the tile's top edge crosses the hero's bottom,
/// which is what makes the two read as one page rather than as a banner with a
/// list under it. Rows of facts appear only when the server has them — an empty
/// chip row is worse than no chip row.
class BrandIdentity extends StatelessWidget {
  const BrandIdentity({super.key, required this.page});

  final BrandPage page;

  /// The logo tile's side. Also the amount of vertical room the name column has
  /// before it starts creeping up onto the stage.
  static const double tile = 92;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final accent = brandAccent(context, page);
    final tagline = page.tagline ?? '';
    final story = page.story ?? '';

    final facts = <Widget>[
      if (page.country != null)
        _FactChip(icon: Icons.public_rounded, label: page.country!, accent: accent),
      if (page.founded != null)
        _FactChip(
          icon: Icons.calendar_today_rounded,
          label: l.brandSince(page.founded!),
          accent: accent,
        ),
      if (page.productCount > 0)
        _FactChip(
          icon: Icons.inventory_2_rounded,
          label: l.brandProductCount(page.productCount),
          accent: accent,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LogoTile(page: page, accent: accent),
            Gap.w16,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if (tagline.isNotEmpty) ...[
                    Gap.h4,
                    Text(
                      tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (facts.isNotEmpty) ...[
          Gap.h16,
          Wrap(spacing: 8, runSpacing: 8, children: facts),
        ],
        if (story.isNotEmpty) ...[
          Gap.h16,
          Text(
            story,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// The mark on its own paper tile. Brand logos are drawn for white, so they get
/// white — the tile is what lets a page tinted in the brand's color still show
/// the brand's own mark honestly.
class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.page, required this.accent});

  final BrandPage page;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      width: BrandIdentity.tile,
      height: BrandIdentity.tile,
      decoration: BoxDecoration(
        color: context.isDark ? cs.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.42 : 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ZbImage(
        url: page.brand.logo,
        padding: const EdgeInsets.all(14),
        backgroundColor: Colors.transparent,
        // A brand with no logo gets its own initial rather than the generic
        // paw: on an identity tile, the paw reads as "some pet product".
        fallback: Center(
          child: Text(
            page.name.characters.take(1).toString().toUpperCase(),
            style: context.tt.displaySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// One stated fact — country, founding year, catalogue size. Tinted with the
/// brand's accent so the row belongs to *this* brand, at the alpha the app uses
/// for every quiet chip.
class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label, required this.accent});

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: context.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          Gap.w6,
          Text(
            label,
            style: context.tt.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
