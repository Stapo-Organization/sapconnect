// Locale-aware month and weekday names (dependency-free — no intl package).

import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

const List<String> _monthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

const List<String> _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _monthsEnShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Sunday-first, matching the Saudi work week (index 0 = الأحد/Sunday).
const List<String> _weekdaysAr = [
  'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
];

const List<String> _weekdaysEn = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

/// Month name for a 1-based [month]. Arabic names, or English (short form
/// available for tight chips/axis labels).
String monthName(int month, {bool short = false}) {
  final i = (month - 1).clamp(0, 11);
  if (AppLocalizations.isArabic) return _monthsAr[i];
  return short ? _monthsEnShort[i] : _monthsEn[i];
}

/// Weekday name for a Sunday-first 0-based [index] (0 = الأحد/Sunday).
String weekdayNameSundayFirst(int index) {
  final i = index.clamp(0, 6);
  return AppLocalizations.isArabic ? _weekdaysAr[i] : _weekdaysEn[i];
}

/// "12 يناير 2026" / "12 January 2026".
String dayMonthYear(DateTime d) => '${d.day} ${monthName(d.month)} ${d.year}';
