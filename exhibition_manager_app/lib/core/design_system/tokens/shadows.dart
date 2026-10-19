import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';

/// Muntajat HUB — Design Tokens: Shadows («المتجر»).
///
/// Shopify-flat: a card is lifted by a 1px line under it, not a cloud. Two
/// working levels — [card] for anything resting on the canvas and [lg] for
/// things floating above it (sheets, menus, toasts). No coloured glows.
class AppShadows {
  AppShadows._();

  static bool get _d => AppThemeController.isDark;

  static List<BoxShadow> get sm => [
        BoxShadow(color: Colors.black.withValues(alpha: _d ? 0.30 : 0.07), blurRadius: 0, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get md => card;

  static List<BoxShadow> get card => [
        BoxShadow(color: Colors.black.withValues(alpha: _d ? 0.35 : 0.07), blurRadius: 0, offset: const Offset(0, 1)),
        BoxShadow(color: Colors.black.withValues(alpha: _d ? 0.20 : 0.04), blurRadius: 3, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(color: Colors.black.withValues(alpha: _d ? 0.45 : 0.10), blurRadius: 16, offset: const Offset(0, 6)),
        BoxShadow(color: Colors.black.withValues(alpha: _d ? 0.30 : 0.05), blurRadius: 3, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> get xl => lg;

  /// Formerly a coloured glow under CTAs — now the same quiet lift as a card,
  /// whatever colour is passed (kept for call-site compatibility).
  static List<BoxShadow> glow(Color color, {double alpha = 0.30}) => sm;
}
