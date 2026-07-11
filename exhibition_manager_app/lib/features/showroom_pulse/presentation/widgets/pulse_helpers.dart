import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';

const Color kBleedingColor = Color(0xFFE5484D); // 🔴 أوقف النزيف
const Color kTrappedColor = Color(0xFFE0A012); // 🟡 حرّر فلوسك
const Color kBasketColor = Color(0xFF12A150); // 🟢 كبّر السلة

/// SAR amount — locale-aware grouping via the shared formatter.
String sar(num v) => sarAmount(v);

String scoreLabel(double s) {
  if (s >= 85) return AppLocalizations.translate('sp_score_excellent');
  if (s >= 70) return AppLocalizations.translate('sp_score_good');
  if (s >= 50) return AppLocalizations.translate('sp_score_average');
  return AppLocalizations.translate('sp_score_needs_attention');
}

String vitalLabel(String key) {
  switch (key) {
    case 'hero_availability':
    case 'capital_efficiency':
    case 'basket_size':
    case 'count_accuracy':
      return AppLocalizations.translate('vital_$key');
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
      return AppLocalizations.translate('sp_health_stockout');
    case 'starved':
      return AppLocalizations.translate('sp_health_starved');
    case 'low':
      return AppLocalizations.translate('sp_health_low');
    case 'overstock':
      return AppLocalizations.translate('sp_health_overstock');
    case 'dead':
      return AppLocalizations.translate('health_dead');
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
