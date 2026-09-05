import 'package:flutter/material.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';

/// The colour a pet owns on the categories screen.
///
/// Four pets, four hues: a customer scrolling the page can tell which aisle
/// they are in from the colour alone, and the same hue follows them into the
/// pet strip so the selected chip and the section it points at agree.
///
/// Resolved from the emoji the server ships (🐱 🐶 🦜 🐹) — the one stable,
/// language-independent handle on "which pet" — and, for a pet the server
/// adds later, from its position, cycling through the same four.
@immutable
class PetPalette {
  const PetPalette._({
    required this.accent,
    required this.onAccent,
    required this.headline,
    required this.muted,
    required this.band,
    required this.bandEnd,
  });

  /// CTA fill and the selected-chip ring.
  final Color accent;
  final Color onAccent;

  /// Headline text on the band.
  final Color headline;

  /// Secondary text on the band.
  final Color muted;

  /// Band gradient, start → end.
  final Color band;
  final Color bandEnd;

  /// The tinted well an illustration sits in on a department card.
  Color well(BuildContext context) => context.isDark
      ? band.withValues(alpha: 0.55)
      : band.withValues(alpha: 0.55);

  /// Wash behind a selected pet chip.
  Color chipFill(BuildContext context) =>
      context.isDark ? band.withValues(alpha: 0.9) : band;

  static const List<String> _order = ['🐱', '🐶', '🦜', '🐹'];

  static PetPalette resolve(
    BuildContext context, {
    String? icon,
    required int index,
  }) {
    var slot = icon == null ? -1 : _order.indexOf(icon.trim());
    if (slot < 0) slot = index % _order.length;
    final dark = context.isDark;
    return switch (slot) {
      0 => dark ? _tealDark : _teal,
      1 => dark ? _coralDark : _coral,
      2 => dark ? _amberDark : _amber,
      _ => dark ? _greenDark : _green,
    };
  }

  static const PetPalette _teal = PetPalette._(
    accent: ZbTokens.teal,
    onAccent: Colors.white,
    headline: ZbTokens.tealDeep,
    muted: ZbTokens.tealDark,
    band: ZbTokens.tealTint,
    bandEnd: ZbTokens.tealTintSoft,
  );
  static const PetPalette _tealDark = PetPalette._(
    accent: ZbTokens.tealOnDark,
    onAccent: ZbTokens.graphite,
    headline: ZbTokens.inkDark,
    muted: ZbTokens.inkSoftDark,
    band: ZbTokens.tealContainerDark,
    bandEnd: ZbTokens.tealContainerDarkEnd,
  );

  static const PetPalette _coral = PetPalette._(
    accent: ZbTokens.coral,
    onAccent: Colors.white,
    headline: ZbTokens.coralDark,
    muted: Color(0xFFA0503F),
    band: ZbTokens.coralTint,
    bandEnd: ZbTokens.coralTintSoft,
  );
  static const PetPalette _coralDark = PetPalette._(
    accent: ZbTokens.coralOnDark,
    onAccent: ZbTokens.graphite,
    headline: ZbTokens.inkDark,
    muted: ZbTokens.inkSoftDark,
    band: ZbTokens.coralContainerDark,
    bandEnd: ZbTokens.coralContainerDarkEnd,
  );

  static const PetPalette _amber = PetPalette._(
    accent: ZbTokens.orange,
    onAccent: Colors.white,
    headline: ZbTokens.amberDeep,
    muted: Color(0xFF9A6A2A),
    band: ZbTokens.amberTint,
    bandEnd: ZbTokens.amberTintSoft,
  );
  static const PetPalette _amberDark = PetPalette._(
    accent: ZbTokens.amberOnDark,
    onAccent: ZbTokens.graphite,
    headline: ZbTokens.inkDark,
    muted: ZbTokens.inkSoftDark,
    band: ZbTokens.amberContainerDark,
    bandEnd: ZbTokens.amberContainerDarkEnd,
  );

  static const PetPalette _green = PetPalette._(
    accent: ZbTokens.success,
    onAccent: Colors.white,
    headline: ZbTokens.greenDeep,
    muted: Color(0xFF3B7A57),
    band: ZbTokens.greenTint,
    bandEnd: ZbTokens.greenTintSoft,
  );
  static const PetPalette _greenDark = PetPalette._(
    accent: ZbTokens.successOnDark,
    onAccent: ZbTokens.graphite,
    headline: ZbTokens.inkDark,
    muted: ZbTokens.inkSoftDark,
    band: ZbTokens.greenContainerDark,
    bandEnd: ZbTokens.greenContainerDarkEnd,
  );
}
