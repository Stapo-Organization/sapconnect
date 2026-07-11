import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';

/// قنوات البيع وهويتها اللونية (mode-aware):
///   الإجمالي = محايد · المعارض = نيلي (هوية التجزئة القائمة) · الجملة = ذهبي.
class SalesChannel {
  SalesChannel._();

  static const String total = 'total';
  static const String retail = 'retail';
  static const String wholesale = 'wholesale';

  /// Segmented-control order (default first).
  static const List<String> order = [total, retail, wholesale];

  /// Text/active color for the channel (readable on light surfaces).
  static Color color(String channel) => switch (channel) {
        wholesale => AppColors.accentDark,
        retail => AppDomain.admin.accent,
        _ => AppColors.textPrimary,
      };

  /// Fill color for bars/strips (wholesale uses the brighter gold).
  static Color fill(String channel) =>
      channel == wholesale ? AppColors.accent : color(channel);

  static String labelKey(String channel) => 'rd_channel_$channel';

  /// الجملة = باليت بضاعة (أيقونة B2B مميّزة — الشحن محجوز لتبويب اللوجستيات).
  static IconData icon(String channel) => switch (channel) {
        wholesale => Icons.pallet,
        retail => Icons.storefront_rounded,
        _ => Icons.donut_large_rounded,
      };

  /// Soft identity gradient for chips/washes (light→transparent of the fill).
  static List<Color> wash(String channel) {
    final c = fill(channel);
    return [c.withValues(alpha: 0.14), c.withValues(alpha: 0.02)];
  }
}

/// إشارة «افتح صفحة الأداء على قناة معيّنة» بين تبويبات شِل المالك.
///
/// The performance tab lives inside an IndexedStack (built once), so a
/// constructor param can't carry a later tap from the home tab. Mirrors the
/// proven [PushService.pendingType] notifier pattern: home sets the value,
/// the mounted performance page listens, consumes, and switches channel.
class PerformanceChannelIntent {
  PerformanceChannelIntent._();

  static final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  /// Read-and-clear.
  static String? consume() {
    final v = pending.value;
    pending.value = null;
    return v;
  }
}
