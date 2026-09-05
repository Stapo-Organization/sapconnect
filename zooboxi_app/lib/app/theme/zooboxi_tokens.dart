import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════
/// ZOOBOXI · Design tokens — هوية زوبوكسي
///
/// Adapted from `docs/zooboxi-brand-kit/tokens/zooboxi_tokens.dart` (the
/// canonical store identity: teal `#429D9C` + coral `#D46856`), with a dark
/// palette added on top. The dark side is *designed*, not inverted: surfaces
/// sit in a desaturated green-graphite family (#121615) so the teal reads as
/// brand rather than as a glowing accent, and coral is lifted toward salmon
/// so it keeps contrast on dark without vibrating.
///
/// This file is the single source of truth for raw color/spacing/radius
/// values. Nothing else in the app should hardcode a hex.
/// ════════════════════════════════════════════════════════════════════
abstract final class ZbTokens {
  // ── Brand · التركواز ───────────────────────────────────────────────
  static const Color teal = Color(0xFF429D9C);
  static const Color tealDark = Color(0xFF2D7A79);
  static const Color tealDeep = Color(0xFF1F5C5B);
  static const Color tealTint = Color(0xFFDCEFEE);
  static const Color mint = Color(0xFFE6F2E6);

  // ── Warm · الكورال والبرتقالي ──────────────────────────────────────
  static const Color coral = Color(0xFFD46856);
  static const Color coralDark = Color(0xFFB14B3B);
  static const Color orange = Color(0xFFD48644);
  static const Color amber = Color(0xFFF4BE2C);
  static const Color peach = Color(0xFFF7DDC7);

  // ── Neutrals · المحايدة (فاتح) ─────────────────────────────────────
  static const Color ink = Color(0xFF2C3E2D);
  static const Color inkSoft = Color(0xFF5C6B5C);
  static const Color line = Color(0xFFE7EBE6);
  static const Color cream = Color(0xFFFFF7EF);
  static const Color paper = Color(0xFFFFFFFF);

  /// Page background in light mode — a hair off pure white so cards read.
  static const Color canvasLight = Color(0xFFF8F9F7);

  // ── Neutrals · المحايدة (داكن) ─────────────────────────────────────
  /// Deepest ground; the app canvas in dark mode.
  static const Color graphite = Color(0xFF121615);

  /// Cards / sheets — one step up from the canvas.
  static const Color graphiteRaised = Color(0xFF1A201E);

  /// Inputs, chips, and the second elevation step.
  static const Color graphiteHigh = Color(0xFF232A28);
  static const Color graphiteHighest = Color(0xFF2C3533);
  static const Color lineDark = Color(0xFF303836);
  static const Color inkDark = Color(0xFFE8EDEA);
  static const Color inkSoftDark = Color(0xFFA3AFAA);

  /// Teal tuned for dark surfaces: lifted lightness, slightly desaturated so
  /// large fills don't glow.
  static const Color tealOnDark = Color(0xFF5FC0BE);
  static const Color tealContainerDark = Color(0xFF19403F);

  /// Coral lifted toward salmon for contrast against graphite.
  static const Color coralOnDark = Color(0xFFF08874);
  static const Color coralContainerDark = Color(0xFF4A241D);
  static const Color amberOnDark = Color(0xFFFBD268);

  // ── Semantic · الحالات ─────────────────────────────────────────────
  static const Color success = Color(0xFF2FA36B);
  static const Color successOnDark = Color(0xFF56C994);
  static const Color warning = Color(0xFFE8A33D);
  static const Color warningOnDark = Color(0xFFF2BE6B);
  static const Color error = Color(0xFFE5484D);
  static const Color errorOnDark = Color(0xFFFF7A7F);

  // ── Delivery tiers · مستويات التوصيل ───────────────────────────────
  /// Express = deep-orange family (urgency without shouting "sale").
  static const Color expressFg = Color(0xFFC2410C);
  static const Color expressBg = Color(0xFFFFF0E6);
  static const Color expressFgDark = Color(0xFFFFA36B);
  static const Color expressBgDark = Color(0xFF3B2116);

  /// Same-day = teal family (the brand's own promise).
  static const Color sameDayFg = tealDeep;
  static const Color sameDayBg = tealTint;
  static const Color sameDayFgDark = tealOnDark;
  static const Color sameDayBgDark = tealContainerDark;

  /// Shipping = neutral (informative, never competes with the fast tiers).
  static const Color shippingFg = Color(0xFF556069);
  static const Color shippingBg = Color(0xFFEDF0F2);
  static const Color shippingFgDark = Color(0xFFA9B4BB);
  static const Color shippingBgDark = Color(0xFF272E31);

  // ── Pet palettes · لوحة كل أليف ────────────────────────────────────
  // The four pets each own a hue on the categories screen so a customer can
  // tell "I'm in the cat aisle" from colour alone. Cats keep the brand teal,
  // dogs the coral, birds a warm amber, small pets a leafy green. Light tints
  // are wash-light; the dark containers are the same hue sunk into graphite.
  static const Color coralTint = Color(0xFFFBE3DC);
  static const Color coralTintSoft = Color(0xFFFDF1EC);
  static const Color tealTintSoft = Color(0xFFEEF7F6);
  static const Color amberTint = Color(0xFFFBEBCF);
  static const Color amberTintSoft = Color(0xFFFDF5E6);
  static const Color amberDeep = Color(0xFF8A5510);
  static const Color amberContainerDark = Color(0xFF3F3117);
  static const Color amberContainerDarkEnd = Color(0xFF2E2513);
  static const Color greenTint = Color(0xFFDDF0E3);
  static const Color greenTintSoft = Color(0xFFEEF7F0);
  static const Color greenDeep = Color(0xFF236A47);
  static const Color greenContainerDark = Color(0xFF1F3A2A);
  static const Color greenContainerDarkEnd = Color(0xFF182C21);
  static const Color tealContainerDarkEnd = Color(0xFF142F2E);
  static const Color coralContainerDarkEnd = Color(0xFF361B16);

  // ── Logo family — decor and mascot moments only ────────────────────
  // Sampled from the Zooboxi mascot logo (cardboard box + dog + cat). These
  // are NOT part of the system palette: they never colour a surface, a CTA or
  // a text style. Use them only for sparkles, hearts, mascot cards and the
  // logo sticker, so the logo's warmth stays a decorative accent.
  static const Color logoCoral = Color(0xFFE67746);
  static const Color logoTeal = Color(0xFF5DAEA7);
  static const Color cardboard = Color(0xFFE49859);
  static const Color inkWarm = Color(0xFF5A2C2F);
  static const Color creamLogo = Color(0xFFF4EBDA);
  static const Color sparkAmber = Color(0xFFE9B36A);

  // ── Radius · الاستدارة ─────────────────────────────────────────────
  static const double rXs = 8;
  static const double rSm = 12;
  static const double rMd = 14;
  static const double rLg = 18;
  static const double rXl = 24;
  static const double rPill = 999;

  // ── Spacing · شبكة 4 ───────────────────────────────────────────────
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;

  // ── Gradients · التدرّجات الموقّعة ──────────────────────────────────
  /// The logo gradient: coral → orange → teal. RTL-agnostic on purpose —
  /// it reads as the brand mark in either direction.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [coral, orange, teal],
    stops: [0.0, 0.38, 1.0],
  );

  static const LinearGradient brandGradientDark = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [coralOnDark, Color(0xFFE0A05F), tealOnDark],
    stops: [0.0, 0.38, 1.0],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDark],
  );
}

/// 4pt spacing gaps — `Gap.h16` reads better at call sites than a bare
/// `SizedBox(height: 16)` and keeps the scale honest.
abstract final class Gap {
  static const Widget h4 = SizedBox(height: 4);
  static const Widget h8 = SizedBox(height: 8);
  static const Widget h12 = SizedBox(height: 12);
  static const Widget h16 = SizedBox(height: 16);
  static const Widget h20 = SizedBox(height: 20);
  static const Widget h24 = SizedBox(height: 24);
  static const Widget h32 = SizedBox(height: 32);

  static const Widget w4 = SizedBox(width: 4);
  static const Widget w6 = SizedBox(width: 6);
  static const Widget w8 = SizedBox(width: 8);
  static const Widget w10 = SizedBox(width: 10);
  static const Widget w12 = SizedBox(width: 12);
  static const Widget w16 = SizedBox(width: 16);
}
