import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/shared/utils/date_names.dart';

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

/// "12 يونيو" / "12 Jun" — short, no year (year shown only when not current).
String shortDate(DateTime? d, {bool withYear = false}) {
  if (d == null) return '—';
  final base = '${d.day} ${monthName(d.month, short: true)}';
  return withYear ? '$base ${d.year}' : base;
}
