import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';

/// Muntajat HUB — Design Tokens: Shadows
///
/// The shadow tint follows the mode: a cool navy on light surfaces, and a
/// stronger black on dark ones (where soft grey shadows would vanish, so cards
/// need a touch more depth to separate from the graphite canvas).
class AppShadows {
  AppShadows._();

  static Color get _tint =>
      AppThemeController.isDark ? Colors.black : const Color(0xFF1E293B);

  /// Dark surfaces swallow soft shadows — lift the opacity so elevation still reads.
  static double get _k => AppThemeController.isDark ? 2.2 : 1.0;

  static List<BoxShadow> get sm => [
        BoxShadow(color: _tint.withValues(alpha: 0.04 * _k), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(color: _tint.withValues(alpha: 0.06 * _k), blurRadius: 8, offset: const Offset(0, 2)),
        BoxShadow(color: _tint.withValues(alpha: 0.04 * _k), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(color: _tint.withValues(alpha: 0.08 * _k), blurRadius: 16, offset: const Offset(0, 4)),
        BoxShadow(color: _tint.withValues(alpha: 0.04 * _k), blurRadius: 6, offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(color: _tint.withValues(alpha: 0.12 * _k), blurRadius: 24, offset: const Offset(0, 8)),
      ];

  /// Soft "floating card" elevation used by the modern component kit.
  static List<BoxShadow> get card => [
        BoxShadow(color: _tint.withValues(alpha: 0.05 * _k), blurRadius: 18, offset: const Offset(0, 6)),
        BoxShadow(color: _tint.withValues(alpha: 0.03 * _k), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  /// Colored glow used under primary CTAs / hero headers.
  static List<BoxShadow> glow(Color color, {double alpha = 0.30}) => [
        BoxShadow(color: color.withValues(alpha: alpha), blurRadius: 20, offset: const Offset(0, 8)),
      ];
}
