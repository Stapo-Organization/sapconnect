import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fixed-slot geometry for [ProductCardView].
///
/// A grid only reads as a grid when every card in a row ends on the same
/// baseline, so the card is assembled from slots of *known* height rather than
/// from whatever its content happens to measure. This class is the single
/// place those heights are computed — which is what lets a grid delegate ask
/// for an exact `mainAxisExtent` and a rail for an exact `SizedBox`, instead of
/// guessing a `childAspectRatio` and hoping. The guess is where the clipped
/// cards came from.
///
/// The OS text scale is honoured but clamped at [maxTextScale], and the card
/// clamps its own text to the same ceiling, so the number computed here and the
/// pixels painted can never disagree.
abstract final class ProductCardMetrics {
  /// Image block, a hair wider than tall: product art is shot on white, and a
  /// true square spends a strip of every card on nothing.
  static const double imageAspect = 1.05;

  static const double border = 1;
  static const double bodyPadding = 10;

  static const double gapBrandName = 2;
  static const double gapNamePrice = 6;
  static const double gapPriceChip = 6;
  static const double gapChipFoot = 8;

  /// Floor for the add / stepper row.
  static const double footFloor = 36;

  /// Rail card width — fixed, so a rail's cards read at the same size as the
  /// grid's beneath it instead of shrinking on a narrow phone.
  static const double railCardWidth = 168;

  /// Grid gutter, shared by the delegate and the width math below.
  static const double gridSpacing = 12;

  /// Past this the slots would eat the image. The card clamps its own text to
  /// the same ceiling rather than letting the layout lie about what fits.
  static const double maxTextScale = 1.3;

  /// The text scale the card actually renders at.
  static TextScaler scalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxTextScale);

  /// Width of one tile in a [crossAxisCount]-column grid inset by
  /// [horizontalPadding].
  static double tileWidth(
    BuildContext context, {
    int crossAxisCount = 2,
    double horizontalPadding = 32,
  }) {
    final available = MediaQuery.sizeOf(context).width -
        horizontalPadding -
        gridSpacing * (crossAxisCount - 1);
    return math.max(0, available) / crossAxisCount;
  }

  /// Total card height for a card [width] wide.
  static double height(BuildContext context, double width) {
    final image = math.max(0.0, width - border * 2) / imageAspect;
    return border * 2 + image + bodyHeight(context);
  }

  /// A hair of give inside the body, absorbed by the spacer between the name
  /// and the price. Two sums of the same doubles in a different order can
  /// differ in the last bit, and `RenderFlex` calls one pixel of that an
  /// overflow — this is cheaper than betting on floating point.
  static const double slack = 1;

  /// Everything below the image: the padded stack of slots.
  static double bodyHeight(BuildContext context) =>
      bodyPadding * 2 +
      slack +
      brandSlot(context) +
      gapBrandName +
      nameSlot(context) +
      gapNamePrice +
      priceSlot(context) +
      gapPriceChip +
      chipSlot(context) +
      gapChipFoot +
      footSlot(context);

  /// Convenience for a two-column grid at the app's standard padding.
  static double gridExtent(BuildContext context, {double horizontalPadding = 32}) =>
      height(context, tileWidth(context, horizontalPadding: horizontalPadding));

  static double brandSlot(BuildContext context) =>
      _line(context, Theme.of(context).textTheme.labelSmall, 11, 1.3);

  /// Exactly two lines, always — a one-line name still ends where a two-line
  /// one does, which is the whole point of the fixed slots.
  static double nameSlot(BuildContext context) =>
      _line(context, Theme.of(context).textTheme.titleSmall, 13.5, 1.4) * 2;

  static double priceSlot(BuildContext context) =>
      _line(context, Theme.of(context).textTheme.titleMedium, 15.5, 1.4);

  /// The delivery-promise / scarcity line. Sized off the label line plus the
  /// compact chip's own 3pt padding, with a little slack so a chip can never
  /// be the thing that overflows.
  static double chipSlot(BuildContext context) {
    final label = _line(context, Theme.of(context).textTheme.labelSmall, 11, 1.3);
    return 6 + math.max(12.0, label);
  }

  /// The add pill / quantity stepper.
  static double footSlot(BuildContext context) {
    final label = _line(context, Theme.of(context).textTheme.labelMedium, 12.5, 1.3);
    return math.max(footFloor, label + 16);
  }

  /// One rendered line of [style]. Every style in the app sets an explicit
  /// `height` with `TextLeadingDistribution.even`, so a line box is exactly
  /// `fontSize × height` — no font-metric guesswork needed.
  static double _line(
    BuildContext context,
    TextStyle? style,
    double fallbackSize,
    double fallbackHeight,
  ) =>
      scalerOf(context).scale(style?.fontSize ?? fallbackSize) *
      (style?.height ?? fallbackHeight);
}
