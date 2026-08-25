import 'package:intl/intl.dart';

/// The new Saudi Riyal symbol. It lives at U+E900 (private use) in the bundled
/// one-glyph `SaudiRiyal` font, which every text style lists in
/// `fontFamilyFallback` — so any `Text` containing this character renders ﷼
/// inline, at the right size, in both languages.
const String riyalSymbol = '\u{E900}';

/// Money, dates and counts.
///
/// One rule holds throughout: **digits are always Western** (1234, never
/// ١٢٣٤). Only the *separators* and word forms follow the language — Arabic
/// gets the Arabic thousands separator `٬` and the Arabic decimal `٫`, English
/// gets `,` and `.`. Mixing numeral families inside one screen (an Arabic date
/// next to a Latin price) is the thing that makes an Arabic UI look cheap.
abstract final class Fmt {
  static bool _ar(String locale) => locale.startsWith('ar');

  static String _thousands(String locale) => _ar(locale) ? '٬' : ',';
  static String _decimal(String locale) => _ar(locale) ? '٫' : '.';

  /// Groups the integer part in threes, Western digits, locale separator.
  static String _grouped(int n, String locale) {
    final sep = _thousands(locale);
    final s = n.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(sep);
      buffer.write(s[i]);
    }
    return (n < 0 ? '-' : '') + buffer.toString();
  }

  /// Plain number: "1٬234٫50" / "1,234.50". Drops `.00` when [trimZeros].
  static String number(num value, {required String locale, int decimals = 2, bool trimZeros = true}) {
    final negative = value < 0;
    final scale = _pow10(decimals);
    // Round the whole amount once, then split. Rounding the fraction on its own
    // lets 1.999 become "1.100" when the carry has nowhere to go.
    final scaled = (value.abs() * scale).round();
    final whole = scaled ~/ scale;
    final fraction = scaled % scale;

    if (decimals == 0 || (trimZeros && fraction == 0)) {
      return (negative ? '-' : '') + _grouped(whole, locale);
    }
    final frac = fraction.toString().padLeft(decimals, '0');
    return '${negative ? '-' : ''}${_grouped(whole, locale)}${_decimal(locale)}$frac';
  }

  /// The money form used everywhere: "1٬234٫50 ﷼".
  ///
  /// The symbol trails the number in both languages — that is how the store
  /// and every Saudi receipt render it, and it keeps RTL/LTR identical.
  static String price(num value, {required String locale, int decimals = 2}) =>
      '${number(value, locale: locale, decimals: decimals)} $riyalSymbol';

  /// Compact magnitude for tight chips: "12.4 ألف" / "12.4K".
  ///
  /// The two Arabic magnitude words are the one place this file carries copy.
  /// They live here rather than in the ARBs on purpose: this is a static
  /// formatter with no `BuildContext`, and "ألف"/"مليون" are number vocabulary
  /// — the same words `intl`'s own compact patterns use — not UI wording a
  /// translator would ever want to reword.
  static String compact(num value, {required String locale}) {
    final ar = _ar(locale);
    final abs = value.abs();
    String trim(double x) =>
        x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
    if (abs >= 1000000) return ar ? '${trim(value / 1000000)} مليون' : '${trim(value / 1000000)}M';
    if (abs >= 1000) return ar ? '${trim(value / 1000)} ألف' : '${trim(value / 1000)}K';
    return _grouped(value.round(), locale);
  }

  /// Compact money for chips: "12.4 ألف ﷼".
  static String compactPrice(num value, {required String locale}) =>
      '${compact(value, locale: locale)} $riyalSymbol';

  /// Percent with the locale's sign: "25٪" / "25%".
  static String percent(num value, {required String locale, int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}${_ar(locale) ? '٪' : '%'}';

  /// Saved-percentage off a sale price, floored so we never over-promise.
  static int discountPercent(num regular, num sale) {
    if (regular <= 0 || sale >= regular) return 0;
    return (((regular - sale) / regular) * 100).floor();
  }

  // ── Dates ──────────────────────────────────────────────────────────

  /// "12 أغسطس" / "Aug 12" — Western digits, localized month names.
  static String dateShort(DateTime date, String locale) =>
      _latin(DateFormat.MMMd(locale).format(date.toLocal()));

  /// "الأربعاء، 12 أغسطس 2026" / "Wed, Aug 12, 2026".
  static String dateFull(DateTime date, String locale) =>
      _latin(DateFormat.yMMMEd(locale).format(date.toLocal()));

  static String dateTime(DateTime date, String locale) =>
      _latin(DateFormat.yMMMd(locale).add_jm().format(date.toLocal()));

  /// "12 أغسطس · 10:14 ص" — the timeline stamp. The year is dropped because a
  /// step of *this* order is always recent enough for it to be noise.
  static String dayTime(DateTime date, String locale) {
    final local = date.toLocal();
    final day = _latin(DateFormat.MMMd(locale).format(local));
    final time = _latin(DateFormat.jm(locale).format(local));
    return '$day · $time';
  }

  /// The weekday index the calendar week starts on. Saudi weeks start Sunday
  /// in both languages of this app.
  static const int firstDayOfWeek = DateTime.sunday;

  /// Normalizes any Arabic-Indic or Eastern-Arabic digits `intl` produced back
  /// to Western digits — one numeral family per screen, always.
  static String _latin(String s) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    var out = s;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(arabicIndic[i], '$i').replaceAll(easternArabic[i], '$i');
    }
    return out;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// Renders a Saudi mobile number for display: `0512345678` → `0512 345 678`.
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return raw;
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }
}
