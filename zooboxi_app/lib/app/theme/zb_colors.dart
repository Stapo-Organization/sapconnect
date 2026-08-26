import 'package:flutter/material.dart';

import 'zooboxi_tokens.dart';

/// A foreground/background pair for a chip or badge. Kept as one object so a
/// call site can never accidentally mix a light `fg` with a dark `bg`.
@immutable
class ZbPair {
  const ZbPair(this.fg, this.bg);

  final Color fg;
  final Color bg;

  static ZbPair lerp(ZbPair a, ZbPair b, double t) =>
      ZbPair(Color.lerp(a.fg, b.fg, t)!, Color.lerp(a.bg, b.bg, t)!);
}

/// Semantic colors that Material's [ColorScheme] has no slot for: delivery
/// tiers, product badges, shimmer, and the brand gradient.
///
/// Read it through `context.zb` (see [ZbColorsX]) rather than
/// `Theme.of(context).extension<ZbColors>()!`.
@immutable
class ZbColors extends ThemeExtension<ZbColors> {
  const ZbColors({
    required this.tierExpress,
    required this.tierSameDay,
    required this.tierShipping,
    required this.tierPickup,
    required this.badgeHot,
    required this.badgeTrending,
    required this.badgeNew,
    required this.badgeLowStock,
    required this.badgeBackInStock,
    required this.success,
    required this.warning,
    required this.sale,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.brandGradient,
  });

  // Delivery tiers — mirror the server's `tier_presentation()` vocabulary.
  final ZbPair tierExpress;
  final ZbPair tierSameDay;
  final ZbPair tierShipping;
  final ZbPair tierPickup;

  // Product badges — mirror `compute_badges()`.
  final ZbPair badgeHot;
  final ZbPair badgeTrending;
  final ZbPair badgeNew;
  final ZbPair badgeLowStock;
  final ZbPair badgeBackInStock;

  final Color success;
  final Color warning;

  /// Sale / discount accent. Coral — used sparingly, never for primary CTAs.
  final Color sale;

  final Color shimmerBase;
  final Color shimmerHighlight;

  final LinearGradient brandGradient;

  static const ZbColors light = ZbColors(
    tierExpress: ZbPair(ZbTokens.expressFg, ZbTokens.expressBg),
    tierSameDay: ZbPair(ZbTokens.sameDayFg, ZbTokens.sameDayBg),
    tierShipping: ZbPair(ZbTokens.shippingFg, ZbTokens.shippingBg),
    tierPickup: ZbPair(Color(0xFF6D4AA8), Color(0xFFF0EBFA)),
    badgeHot: ZbPair(Color(0xFFB3261E), Color(0xFFFDE7E4)),
    badgeTrending: ZbPair(Color(0xFF9A5B00), Color(0xFFFDF0DC)),
    badgeNew: ZbPair(ZbTokens.tealDeep, ZbTokens.tealTint),
    badgeLowStock: ZbPair(Color(0xFF8A5A00), Color(0xFFFFF3D6)),
    badgeBackInStock: ZbPair(Color(0xFF1B6E4B), Color(0xFFDFF3E8)),
    success: ZbTokens.success,
    warning: ZbTokens.warning,
    sale: ZbTokens.coral,
    shimmerBase: Color(0xFFEBEEEC),
    shimmerHighlight: Color(0xFFF7F9F8),
    brandGradient: ZbTokens.brandGradient,
  );

  static const ZbColors dark = ZbColors(
    tierExpress: ZbPair(ZbTokens.expressFgDark, ZbTokens.expressBgDark),
    tierSameDay: ZbPair(ZbTokens.sameDayFgDark, ZbTokens.sameDayBgDark),
    tierShipping: ZbPair(ZbTokens.shippingFgDark, ZbTokens.shippingBgDark),
    tierPickup: ZbPair(Color(0xFFC0A8ED), Color(0xFF2A2340)),
    badgeHot: ZbPair(Color(0xFFFF8F86), Color(0xFF3E1D1A)),
    badgeTrending: ZbPair(Color(0xFFF0B968), Color(0xFF3A2A13)),
    badgeNew: ZbPair(ZbTokens.tealOnDark, ZbTokens.tealContainerDark),
    badgeLowStock: ZbPair(Color(0xFFEFC169), Color(0xFF3A2D12)),
    badgeBackInStock: ZbPair(Color(0xFF6ED3A2), Color(0xFF14301F)),
    success: ZbTokens.successOnDark,
    warning: ZbTokens.warningOnDark,
    sale: ZbTokens.coralOnDark,
    shimmerBase: Color(0xFF1E2523),
    shimmerHighlight: Color(0xFF2A3230),
    brandGradient: ZbTokens.brandGradientDark,
  );

  /// Resolves a server `tier` string (`express` / `same_day` / `shipping` /
  /// `pickup`) to its pair. Unknown tiers fall back to the neutral shipping
  /// pair rather than throwing — the server can add tiers before the app knows.
  ZbPair tier(String? key) => switch (key) {
        'express' => tierExpress,
        'same_day' || 'sameday' || 'city' => tierSameDay,
        'pickup' => tierPickup,
        _ => tierShipping,
      };

  /// Resolves a server badge `type` to its pair.
  ZbPair badge(String? type) => switch (type) {
        'hot' || 'bestseller' => badgeHot,
        'trending' => badgeTrending,
        'new' => badgeNew,
        'low_stock' || 'low-stock' => badgeLowStock,
        'back_in_stock' || 'back-in-stock' => badgeBackInStock,
        _ => badgeNew,
      };

  @override
  ZbColors copyWith({
    ZbPair? tierExpress,
    ZbPair? tierSameDay,
    ZbPair? tierShipping,
    ZbPair? tierPickup,
    ZbPair? badgeHot,
    ZbPair? badgeTrending,
    ZbPair? badgeNew,
    ZbPair? badgeLowStock,
    ZbPair? badgeBackInStock,
    Color? success,
    Color? warning,
    Color? sale,
    Color? shimmerBase,
    Color? shimmerHighlight,
    LinearGradient? brandGradient,
  }) {
    return ZbColors(
      tierExpress: tierExpress ?? this.tierExpress,
      tierSameDay: tierSameDay ?? this.tierSameDay,
      tierShipping: tierShipping ?? this.tierShipping,
      tierPickup: tierPickup ?? this.tierPickup,
      badgeHot: badgeHot ?? this.badgeHot,
      badgeTrending: badgeTrending ?? this.badgeTrending,
      badgeNew: badgeNew ?? this.badgeNew,
      badgeLowStock: badgeLowStock ?? this.badgeLowStock,
      badgeBackInStock: badgeBackInStock ?? this.badgeBackInStock,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      sale: sale ?? this.sale,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  ZbColors lerp(ThemeExtension<ZbColors>? other, double t) {
    if (other is! ZbColors) return this;
    return ZbColors(
      tierExpress: ZbPair.lerp(tierExpress, other.tierExpress, t),
      tierSameDay: ZbPair.lerp(tierSameDay, other.tierSameDay, t),
      tierShipping: ZbPair.lerp(tierShipping, other.tierShipping, t),
      tierPickup: ZbPair.lerp(tierPickup, other.tierPickup, t),
      badgeHot: ZbPair.lerp(badgeHot, other.badgeHot, t),
      badgeTrending: ZbPair.lerp(badgeTrending, other.badgeTrending, t),
      badgeNew: ZbPair.lerp(badgeNew, other.badgeNew, t),
      badgeLowStock: ZbPair.lerp(badgeLowStock, other.badgeLowStock, t),
      badgeBackInStock: ZbPair.lerp(badgeBackInStock, other.badgeBackInStock, t),
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      sale: Color.lerp(sale, other.sale, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      brandGradient: LinearGradient.lerp(brandGradient, other.brandGradient, t)!,
    );
  }
}

/// Parses a brand-kit hex (`#429D9C`, `429D9C`, `#FF429D9C`) to a [Color].
///
/// Brand accents come from the store's kit as strings, so the failure mode has
/// to be "no tint" rather than a crash: one brand with a typo'd accent must not
/// take the strip down with it.
Color? hexColor(String? value) {
  final raw = value?.trim().replaceFirst('#', '');
  if (raw == null || (raw.length != 6 && raw.length != 8)) return null;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return null;
  return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
}

/// Terse theme accessors. `context.zb.tierExpress`, `context.cs.primary`,
/// `context.tt.titleMedium`.
extension ZbColorsX on BuildContext {
  ZbColors get zb => Theme.of(this).extension<ZbColors>() ?? ZbColors.light;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
