import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';

/// «مركز القيادة» (وضع المالك) — طبقة أسماء دلالية رفيعة فوق [AppColors].
///
/// سابقاً كانت هوية سليت داكنة ثابتة. الآن صار للتطبيق وضعان (فاتح نيلي/داكن
/// جرافيت) يختارهما المستخدم، فحوّلنا هذه الثوابت إلى محوّلات (getters) تشير إلى
/// توكنز [AppColors] المتبدّلة — فيتلوّن مركز القيادة تلقائياً مع الوضع المختار،
/// دون لمس صفحات المالك التي تستهلك هذه الأسماء.
class OwnerTheme {
  OwnerTheme._();

  // ─── الأسطح ───
  static Color get bg => AppColors.background;
  static Color get surface => AppColors.surface;
  static Color get surfaceHi => AppColors.surfaceVariant;
  static Color get hairline => AppColors.border;

  // ─── النص ───
  static Color get textHi => AppColors.textPrimary;
  static Color get textMuted => AppColors.textSecondary;

  // ─── لون التمييز التفاعلي ───
  static Color get accent => AppColors.primary;

  // ─── ألوان المؤشّرات الدلالية ───
  static Color get positive => AppColors.success;
  static Color get danger => AppColors.error;
  static Color get caution => AppColors.warning;
  static Color get info => AppColors.info;

  /// تدرّج الهيرو — يتبع وضع التطبيق (نيلي في الفاتح، جرافيت في الداكن).
  static LinearGradient get heroGradient => AppColors.heroGradient;
}
