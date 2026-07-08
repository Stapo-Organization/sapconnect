import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';

const Color kBleedingColor = Color(0xFFE5484D); // 🔴 أوقف النزيف
const Color kTrappedColor = Color(0xFFE0A012); // 🟡 حرّر فلوسك
const Color kBasketColor = Color(0xFF12A150); // 🟢 كبّر السلة

/// SAR with Arabic thousands separator (Western digits).
String sar(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return '${b.toString()} \u{E900}';
}

String scoreLabel(double s) {
  if (s >= 85) return 'ممتاز';
  if (s >= 70) return 'جيد';
  if (s >= 50) return 'متوسط';
  return 'يحتاج انتباه';
}

String vitalLabel(String key) {
  switch (key) {
    case 'hero_availability':
      return 'توفر الأبطال';
    case 'capital_efficiency':
      return 'كفاءة رأس المال';
    case 'basket_size':
      return 'حجم السلة';
    case 'count_accuracy':
      return 'دقة الجرد';
    default:
      return key;
  }
}

Color vitalColor(double pct, bool hasValue) {
  if (!hasValue) return const Color(0xFFCBD5E1);
  if (pct >= 80) return AppColors.success;
  if (pct >= 60) return AppColors.warning;
  return AppColors.error;
}

String healthLabel(String h) {
  switch (h) {
    case 'stockout':
      return 'نفد';
    case 'starved':
      return 'ينفد باستمرار';
    case 'low':
      return 'على وشك النفاد';
    case 'overstock':
      return 'فائض راكد';
    case 'dead':
      return 'راكد';
    default:
      return h;
  }
}

Color healthColor(String h) {
  switch (h) {
    case 'stockout':
      return AppColors.error;
    case 'starved':
    case 'low':
      return AppColors.warning;
    case 'overstock':
      return kTrappedColor;
    case 'dead':
      return AppColors.textTertiary;
    default:
      return AppColors.textSecondary;
  }
}

/// Rounded product thumbnail with a graceful fallback icon.
Widget productThumb(String? url, {double size = 56, Color? accent}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F9),
      borderRadius: AppRadius.borderMd,
      border: Border.all(
        color: (accent ?? AppColors.border).withValues(alpha: 0.18),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: (url == null || url.isEmpty)
        ? Icon(
            Icons.inventory_2_outlined,
            size: size * 0.46,
            color: AppColors.textTertiary,
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(
              Icons.inventory_2_outlined,
              size: size * 0.46,
              color: AppColors.textTertiary,
            ),
          ),
  );
}
