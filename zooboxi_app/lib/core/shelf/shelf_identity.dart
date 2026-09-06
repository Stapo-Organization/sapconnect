import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import 'shelf_controller.dart';

/// Each storefront's personality — the one place its colours, glyph and
/// voice live, so the tab, the ribbon and the switch animation can never
/// drift apart.
///
/// إكسبريس is ember: heat, bolts, a promise measured in minutes. زوبكسي is
/// the brand's own teal: the whole calm catalogue. The identities are
/// deliberately far apart — the owner's brief is that crossing the tabs
/// should feel like walking into a different shop, and that starts with the
/// chrome disagreeing about its colour.
@immutable
class ShelfIdentity {
  const ShelfIdentity._({
    required this.shelf,
    required this.icon,
    required this.accent,
    required this.onAccent,
    required this.thumb,
    required this.ribbon,
    required this.onRibbon,
    required this.spark,
  });

  final Shelf shelf;
  final IconData icon;

  /// The store's signature colour — selected text, glows, small accents.
  final Color accent;
  final Color onAccent;

  /// The sliding thumb behind the active tab.
  final LinearGradient thumb;

  /// The promise ribbon under the header.
  final LinearGradient ribbon;
  final Color onRibbon;

  /// The one-shot sparkle that greets a switch.
  final Color spark;

  static ShelfIdentity of(BuildContext context, Shelf shelf) {
    final dark = context.isDark;
    return switch (shelf) {
      Shelf.express => dark ? _emberDark : _ember,
      Shelf.all => dark ? _tealDark : _teal,
    };
  }

  // ── إكسبريس · ember ────────────────────────────────────────────────
  static const ShelfIdentity _ember = ShelfIdentity._(
    shelf: Shelf.express,
    icon: Icons.bolt_rounded,
    accent: Color(0xFFD9540F),
    onAccent: Colors.white,
    thumb: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [Color(0xFFE8641F), Color(0xFFC2410C)],
    ),
    ribbon: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [Color(0xFFB94510), Color(0xFFDB6A22)],
    ),
    onRibbon: Colors.white,
    spark: ZbTokens.amber,
  );

  static const ShelfIdentity _emberDark = ShelfIdentity._(
    shelf: Shelf.express,
    icon: Icons.bolt_rounded,
    accent: Color(0xFFFFA36B),
    onAccent: Colors.white,
    thumb: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [Color(0xFFD9540F), Color(0xFF9A3A0E)],
    ),
    ribbon: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [Color(0xFF57280F), Color(0xFF3B2116)],
    ),
    onRibbon: Color(0xFFFFC79E),
    spark: ZbTokens.amberOnDark,
  );

  // ── زوبكسي · teal ──────────────────────────────────────────────────
  static const ShelfIdentity _teal = ShelfIdentity._(
    shelf: Shelf.all,
    icon: Icons.storefront_rounded,
    accent: ZbTokens.tealDeep,
    onAccent: Colors.white,
    thumb: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [ZbTokens.teal, ZbTokens.tealDark],
    ),
    ribbon: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [ZbTokens.tealDeep, ZbTokens.tealDark],
    ),
    onRibbon: Colors.white,
    spark: ZbTokens.logoTeal,
  );

  static const ShelfIdentity _tealDark = ShelfIdentity._(
    shelf: Shelf.all,
    icon: Icons.storefront_rounded,
    accent: ZbTokens.tealOnDark,
    onAccent: ZbTokens.graphite,
    thumb: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [ZbTokens.tealOnDark, ZbTokens.tealDark],
    ),
    ribbon: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [ZbTokens.tealContainerDark, ZbTokens.tealContainerDarkEnd],
    ),
    onRibbon: ZbTokens.inkDark,
    spark: ZbTokens.tealOnDark,
  );
}
