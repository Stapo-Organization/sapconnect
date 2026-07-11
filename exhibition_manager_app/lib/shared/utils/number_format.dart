// Lightweight, dependency-free number formatting for the admin screens.
// Locale-aware: Western digits everywhere; the thousands separator, magnitude
// words (مليون/ألف ↔ M/K) and the percent sign follow the active language.

import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// The new Saudi Riyal symbol. It lives at U+E900 in the bundled `SaudiRiyal`
/// font, reached via [AppTypography.fontFamilyFallback] — so any Text that
/// includes this character renders the official ﷼ glyph inline, in both AR/EN.
const String riyalSymbol = '\u{E900}';

/// Percent sign for the active language: ٪ in Arabic, % in English.
String get pctSign => AppLocalizations.isArabic ? '٪' : '%';

/// "12٪" / "12%" — rounded percentage with the locale's sign.
String pctLabel(num v, {int digits = 0}) => '${v.toStringAsFixed(digits)}$pctSign';

String _grouped(int n) {
  final sep = AppLocalizations.isArabic ? '٬' : ',';
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

/// SAR amount, rounded, grouped: e.g. "12٬450 ﷼" / "12,450 ﷼".
String sarAmount(num v) => '${_grouped(v.round())} $riyalSymbol';

/// Compact SAR for tight chips: "12.4 ألف ﷼" / "12.4K ﷼".
String sarCompact(num v) => '${compactNum(v)} $riyalSymbol';

/// Plain grouped integer.
String intGrouped(num v) => _grouped(v.round());

/// Units count, dropping a trailing .0.
String unitsLabel(num v) {
  if (v == v.roundToDouble()) return _grouped(v.round());
  return v.toStringAsFixed(1);
}

/// Compact magnitude WITHOUT currency: "19 ألف" / "19K" · "1.2 مليون" / "1.2M".
/// Drops a trailing .0 so chips stay short.
String compactNum(num v) {
  final ar = AppLocalizations.isArabic;
  final a = v.abs();
  String trim(double x) => x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
  if (a >= 1000000) return ar ? '${trim(v / 1000000)} مليون' : '${trim(v / 1000000)}M';
  if (a >= 1000) return ar ? '${trim(v / 1000)} ألف' : '${trim(v / 1000)}K';
  return _grouped(v.round());
}
