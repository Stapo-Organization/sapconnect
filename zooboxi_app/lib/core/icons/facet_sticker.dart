import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'facet_stickers.g.dart';

/// A filter sticker — life stages, food forms, flavours, needs — drawn in
/// the character library's own language (maroon outline, flat colour, one
/// white gloss), so the filters look like they belong to the same cast.
///
/// The key comes from the store («فهرس الفلاتر» sends `icon: 'kitten'`); an
/// unknown key draws nothing but keeps its box, so a row never shifts.
class FacetSticker extends StatelessWidget {
  const FacetSticker(this.name, {super.key, this.size = 28, this.dimmed = false});

  final String? name;
  final double size;

  /// A value with nothing behind it: faded and greyed, never hidden.
  final bool dimmed;

  static bool has(String? name) => name != null && facetStickerSvgs.containsKey(name);

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final svg = name == null ? null : facetStickerSvgs[name];
    if (svg == null) return SizedBox.square(dimension: size);
    Widget art = SvgPicture.string(svg, width: size, height: size, excludeFromSemantics: true);
    if (dimmed) {
      art = Opacity(opacity: 0.38, child: ColorFiltered(colorFilter: _grey, child: art));
    }
    return SizedBox.square(dimension: size, child: art);
  }
}
