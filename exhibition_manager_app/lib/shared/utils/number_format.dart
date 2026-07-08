// Lightweight, dependency-free number formatting for the admin screens.
// Western digits with an Arabic thousands separator (٬), matching pulse_helpers.

/// The new Saudi Riyal symbol. It lives at U+E900 in the bundled `SaudiRiyal`
/// font, reached via [AppTypography.fontFamilyFallback] — so any Text that
/// includes this character renders the official ﷼ glyph inline, in both AR/EN.
const String riyalSymbol = '\u{E900}';

String _grouped(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

/// SAR amount, rounded, grouped: e.g. "12٬450 ﷼".
String sarAmount(num v) => '${_grouped(v.round())} $riyalSymbol';

/// Compact SAR for tight chips: 12.4 ألف / 1.2 مليون.
String sarCompact(num v) {
  final a = v.abs();
  if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} مليون $riyalSymbol';
  if (a >= 1000) return '${(v / 1000).toStringAsFixed(1)} ألف $riyalSymbol';
  return sarAmount(v);
}

/// Plain grouped integer.
String intGrouped(num v) => _grouped(v.round());

/// Units count, dropping a trailing .0.
String unitsLabel(num v) {
  if (v == v.roundToDouble()) return _grouped(v.round());
  return v.toStringAsFixed(1);
}

/// Compact magnitude WITHOUT currency: "19 ألف" / "1.2 مليون" / "850".
/// Drops a trailing .0 so chips stay short.
String compactNum(num v) {
  final a = v.abs();
  String trim(double x) => x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
  if (a >= 1000000) return '${trim(v / 1000000)} مليون';
  if (a >= 1000) return '${trim(v / 1000)} ألف';
  return _grouped(v.round());
}
