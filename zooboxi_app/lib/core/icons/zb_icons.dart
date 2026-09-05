import 'package:flutter/material.dart';

import '../../app/theme/zooboxi_tokens.dart';
import 'painters/icon_painter.dart';
import 'painters/nav_icons.dart';
import 'painters/object_icons.dart';

export 'painters/icon_painter.dart' show ZbIconPainter;

/// ════════════════════════════════════════════════════════════════════
/// ZbIcons — the app's own icon language
///
/// Material's icon set is a different drawing than the Zooboxi logo: thin,
/// geometric, cold. These are drawn in the logo's hand instead — one 24-unit
/// grid, one thick warm-brown outline, bubbly proportions, and a [fill] that
/// turns an outline into a filled kawaii sticker. That single parameter is
/// what a tab selection animates, so selection reads as the glyph *coming to
/// life* rather than as a swap between two unrelated shapes.
///
/// They are used only where the app's own character belongs: the tab bar, the
/// header, the heart, the add control, the pin. Everything else stays
/// Material — a set this expressive stops meaning anything if it labels every
/// row in a settings list.
/// ════════════════════════════════════════════════════════════════════
enum ZbIconKind {
  home,
  categories,
  cart,
  bag,
  account,
  heart,
  search,
  scan,
  pin,
  bell,
  paw,
  plusBox,
  plus,
  sparkle,
}

/// The outline colour an icon uses when the call site does not name one: the
/// logo's warm brown on light, its cream on dark.
Color resolveZbInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? ZbTokens.creamLogo.withValues(alpha: 0.92)
        : ZbTokens.inkWarm;

/// Supplies the default ink to a subtree — a coloured canvas sets it once
/// instead of every icon under it repeating `ink: Colors.white`.
class ZbIconTheme extends InheritedWidget {
  const ZbIconTheme({super.key, required this.ink, required super.child});

  final Color ink;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZbIconTheme>()?.ink ??
      resolveZbInk(context);

  @override
  bool updateShouldNotify(ZbIconTheme oldWidget) => oldWidget.ink != ink;
}

/// One painted icon. Const-friendly and cheap: it owns a single [CustomPaint]
/// and allocates only its own path.
class ZbIcon extends StatelessWidget {
  const ZbIcon(
    this.kind, {
    super.key,
    this.size = 24,
    this.fill = 0,
    this.ink,
    this.tint,
    this.lidOpen = 0,
    this.smile = 0.6,
    this.scanY = 0,
  });

  final ZbIconKind kind;
  final double size;

  /// 0 = outline only, 1 = the full sticker. Fractions crossfade the fills.
  final double fill;

  /// Outline colour. Defaults to [ZbIconTheme.of].
  final Color? ink;

  /// Overrides the icon's signature accent, for surfaces that need one colour.
  final Color? tint;

  /// [ZbIconKind.cart] only — how far the lid flaps have swung open.
  final double lidOpen;

  /// [ZbIconKind.cart] only — how wide the box is smiling.
  final double smile;

  /// [ZbIconKind.scan] only — where the scan line sits, top (0) to bottom (1).
  final double scanY;

  @override
  Widget build(BuildContext context) {
    final resolved = ink ?? ZbIconTheme.of(context);
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _painter(resolved, rtl),
      ),
    );
  }

  ZbIconPainter _painter(Color resolved, bool rtl) {
    final f = fill.clamp(0.0, 1.0);
    final s = size;
    return switch (kind) {
      ZbIconKind.home =>
        ZbHomePainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.categories =>
        ZbCategoriesPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.cart => ZbCartPainter(
          ink: resolved,
          fill: f,
          size: s,
          tint: tint,
          rtl: rtl,
          lidOpen: lidOpen.clamp(0.0, 1.0),
          smile: smile.clamp(0.0, 1.0),
        ),
      ZbIconKind.plus =>
        ZbPlusPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.bag =>
        ZbBagPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.account =>
        ZbAccountPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.heart =>
        ZbHeartPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.search =>
        ZbSearchPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.scan => ZbScanPainter(
          ink: resolved,
          fill: f,
          size: s,
          tint: tint,
          rtl: rtl,
          scanY: scanY,
        ),
      ZbIconKind.pin =>
        ZbPinPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.bell =>
        ZbBellPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.paw =>
        ZbPawPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.plusBox =>
        ZbPlusBoxPainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
      ZbIconKind.sparkle =>
        ZbSparklePainter(ink: resolved, fill: f, size: s, tint: tint, rtl: rtl),
    };
  }
}
