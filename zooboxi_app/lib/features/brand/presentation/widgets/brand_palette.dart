import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../catalog/data/catalog_models.dart';

/// A brand's colours, worked out for a page.
///
/// A kit accent is chosen for a logo on white, not for a screen: INABA's
/// orange cannot carry white words (2.2:1) and Josera's yellow cannot carry
/// any light ink at all. So every role is derived from the accent's hue and
/// checked for contrast: the stage keeps the brand's exact colour, and the
/// words on it turn deep brown or white, whichever actually reads.
@immutable
class BrandPalette {
  const BrandPalette({
    required this.field,
    required this.ring,
    required this.ink,
    required this.deep,
    required this.wash,
    required this.tint,
    required this.stripe,
    required this.band,
    required this.bandInk,
  });

  /// The stage: the brand's own accent, untouched.
  final Color field;

  /// The lighter disc the products stand in front of.
  final Color ring;

  /// Words on [field].
  final Color ink;

  /// The brand's colour as text and icons on the page surface.
  final Color deep;

  /// Tile ground and chip fill on the page surface.
  final Color wash;

  /// Tile rings and the disc behind a tile's product.
  final Color tint;

  /// The kit's second colour — a thin bar at the stage's start edge.
  final Color stripe;

  /// A deep brand tone that carries white words (the value band).
  final Color band;

  /// The brand's colour lifted to read on [band].
  final Color bandInk;

  /// Whether the stage wants dark status-bar icons.
  bool get fieldIsLight => field.computeLuminance() > 0.35;

  static BrandPalette of(BuildContext context, BrandPage page) =>
      from(context, accent: page.brand.accent, accentDark: page.accentDark);

  /// The same roles from a brand's two kit colours alone — for the surfaces
  /// that know a brand only by its summary (home cards, search, the cart).
  static BrandPalette ofSummary(BuildContext context, BrandSummary brand) =>
      from(context, accent: brand.accent, accentDark: brand.accentDark);

  static BrandPalette from(BuildContext context, {String? accent, String? accentDark}) {
    final base = hexColor(accent) ?? ZbTokens.teal;
    final second = hexColor(accentDark) ?? _atL(base, 0.28);
    final surface = context.cs.surface;
    final hsl = HSLColor.fromColor(base);
    final sat = hsl.saturation;
    final dark = context.isDark;

    final ink = contrast(base, Colors.white) >= 4.5 ? Colors.white : _readableOn(base);

    return BrandPalette(
      field: base,
      ring: _atL(base, (hsl.lightness + 0.08).clamp(0.0, 0.92)),
      ink: ink,
      deep: _reach(base, surface, 4.5),
      wash: dark ? _hsl(hsl.hue, sat.clamp(0, 0.35), 0.15) : _hsl(hsl.hue, sat.clamp(0, 0.9), 0.965),
      tint: dark ? _hsl(hsl.hue, sat.clamp(0, 0.40), 0.24) : _hsl(hsl.hue, sat.clamp(0, 0.85), 0.88),
      stripe: second,
      band: _hsl(hsl.hue, sat.clamp(0, 0.7), 0.15),
      bandInk: _reach(_hsl(hsl.hue, sat.clamp(0, 0.95), 0.62), _hsl(hsl.hue, sat.clamp(0, 0.7), 0.15), 4.5),
    );
  }

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static Color _hsl(double hue, double sat, double light) =>
      HSLColor.fromAHSL(1, hue, sat.toDouble(), light).toColor();

  static Color _atL(Color color, double lightness) =>
      HSLColor.fromColor(color).withLightness(lightness.clamp(0.0, 1.0)).toColor();

  /// The accent's own hue, darkened into a deep ink that reads on it.
  static Color _readableOn(Color field) {
    final hsl = HSLColor.fromColor(field);
    final ink = _hsl(hsl.hue, hsl.saturation.clamp(0, 0.75), 0.13);
    return contrast(field, ink) >= 4.5 ? ink : const Color(0xFF1A1A1A);
  }

  /// Walks [color]'s lightness away from [ground] until the pair reaches
  /// [ratio] — the brand's hue at the nearest lightness that reads.
  static Color _reach(Color color, Color ground, double ratio) {
    if (contrast(color, ground) >= ratio) return color;
    final hsl = HSLColor.fromColor(color);
    final down = ground.computeLuminance() > 0.4;
    var l = hsl.lightness;
    for (var i = 0; i < 50; i++) {
      l = (l + (down ? -0.02 : 0.02)).clamp(0.0, 1.0);
      final c = hsl.withLightness(l).toColor();
      if (contrast(c, ground) >= ratio) return c;
    }
    return down ? const Color(0xFF1A1A1A) : Colors.white;
  }
}
