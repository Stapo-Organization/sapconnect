import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Shared visual language for the container board: the server-derived
/// `state_color` key → a concrete accent, plus a light RTL-friendly date format.
Color containerStateColor(String key) {
  switch (key) {
    case 'emerald': // delivered
      return AppColors.success;
    case 'rose': // overdue
      return AppColors.error;
    case 'amber': // arriving soon
      return const Color(0xFFE0A012);
    case 'cyan': // in transit
      return const Color(0xFF0E9BB0);
    case 'slate': // pending / being prepared
    default:
      return const Color(0xFF64748B);
  }
}

const _arMonths = [
  '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const _enMonths = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 يونيو" / "12 Jun" — short, no year (year shown only when not current).
String shortDate(DateTime? d, {bool withYear = false}) {
  if (d == null) return '—';
  final months = AppLocalizations.isArabic ? _arMonths : _enMonths;
  final base = '${d.day} ${months[d.month]}';
  return withYear ? '$base ${d.year}' : base;
}
