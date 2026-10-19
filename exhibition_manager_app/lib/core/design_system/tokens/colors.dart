import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';

/// Muntajat HUB — Design Tokens: Colors («المتجر», chosen 2026-10-08).
///
/// Shopify-calm: a neutral grey canvas, white surfaces, near-black for actions
/// and selection, and colour reserved for meaning (success / caution /
/// critical / info). There is ONE accent — sections are told apart by their
/// icons, not by hue.
///
///   • **Light:** canvas #F1F1F1, ink #303030, actions near-black.
///   • **Dark:** graphite canvas #1A1A1A; actions take the Muntajat blue so a
///     filled control (white label) and a tinted glyph both stay legible.
///
/// Every value is a getter keyed on [AppThemeController.isDark], so switching
/// the mode and rebuilding recolours the whole app.
class AppColors {
  AppColors._();

  static bool get _d => AppThemeController.isDark;

  // ─── Action / selection ────────────────────────────────────
  static Color get primary => _d ? const Color(0xFF4F86C6) : const Color(0xFF303030);
  static Color get primaryLight => _d ? const Color(0xFF6B9BD3) : const Color(0xFF4A4A4A);
  static Color get primaryDark => _d ? const Color(0xFF3E72B0) : const Color(0xFF1A1A1A);
  static Color get primaryDeep => _d ? const Color(0xFF2F5E96) : const Color(0xFF0F0F0F);
  static Color get primaryContainer => _d ? const Color(0xFF243243) : const Color(0xFFEBEBEB);
  static Color get secondary => _d ? const Color(0xFF303030) : const Color(0xFFF1F1F1);

  /// Links and focus rings (the one place blue shows in light mode).
  static Color get link => _d ? const Color(0xFF7FB0F0) : const Color(0xFF005BD3);

  /// Warm accent kept only for points / achievements.
  static Color get accent => _d ? const Color(0xFFE0B04A) : const Color(0xFFB98900);
  static Color get accentDark => _d ? const Color(0xFFC8962E) : const Color(0xFF8A6600);
  static Color get accentSoft => _d ? const Color(0xFF332A14) : const Color(0xFFFFF3CC);

  // ─── Semantic (meaning, never decoration) ──────────────────
  static Color get success => _d ? const Color(0xFF4FBF86) : const Color(0xFF29845A);
  static Color get successLight => _d ? const Color(0xFF15301F) : const Color(0xFFCDFEE1);
  static Color get warning => _d ? const Color(0xFFE0B03A) : const Color(0xFFB07D00);
  static Color get warningLight => _d ? const Color(0xFF3A3210) : const Color(0xFFFFF1B8);
  static Color get error => _d ? const Color(0xFFF0827A) : const Color(0xFFD72C0D);
  static Color get errorLight => _d ? const Color(0xFF3A1C1A) : const Color(0xFFFEE9E8);
  static Color get info => _d ? const Color(0xFF6FA8FF) : const Color(0xFF005BD3);
  static Color get infoLight => _d ? const Color(0xFF1A2A40) : const Color(0xFFEAF4FF);

  // ─── Surfaces ──────────────────────────────────────────────
  static Color get background => _d ? const Color(0xFF1A1A1A) : const Color(0xFFF1F1F1);
  static Color get surface => _d ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => _d ? const Color(0xFF303030) : const Color(0xFFF7F7F7);
  static Color get cardBackground => surface;

  // ─── Text ──────────────────────────────────────────────────
  static Color get textPrimary => _d ? const Color(0xFFF1F1F1) : const Color(0xFF303030);
  static Color get textSecondary => _d ? const Color(0xFFB5B5B5) : const Color(0xFF616161);
  static Color get textTertiary => _d ? const Color(0xFF8F8F8F) : const Color(0xFF767676);
  static Color get textOnPrimary => const Color(0xFFFFFFFF);
  static Color get textOnDark => const Color(0xFFFFFFFF);

  // ─── Lines ─────────────────────────────────────────────────
  static Color get border => _d ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
  static Color get borderLight => _d ? const Color(0xFF333333) : const Color(0xFFEBEBEB);
  static Color get divider => borderLight;

  /// Input outline at rest (Polaris uses a darker stroke than card borders).
  static Color get inputBorder => _d ? const Color(0xFF555555) : const Color(0xFF8A8A8A);

  // ─── Status (kept for existing call sites) ─────────────────
  static Color get statusNew => info;
  static Color get statusShipped => warning;
  static Color get statusReceived => success;
  static Color get statusCompleted => success;
  static Color get statusInProgress => warning;
  static Color get statusCancelled => error;

  // ─── Fills (formerly gradients — kept flat on purpose) ─────
  static LinearGradient get primaryGradient => LinearGradient(colors: [primary, primary]);
  static LinearGradient get accentGradient => LinearGradient(colors: [accent, accent]);

  /// Dark summary panel — near-black in light mode, raised graphite in dark.
  /// White type on top stays legible in both.
  static LinearGradient get heroGradient => _d
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2E2E), Color(0xFF262626)],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF303030), Color(0xFF1F1F1F)],
        );

  static LinearGradient get goldGradient => LinearGradient(colors: [accent, accentDark]);
  static LinearGradient get successGradient => LinearGradient(colors: [success, success]);

  // ─── Shimmer (skeletons) ───────────────────────────────────
  static Color get shimmerBase => _d ? const Color(0xFF2E2E2E) : const Color(0xFFEBEBEB);
  static Color get shimmerHighlight => _d ? const Color(0xFF383838) : const Color(0xFFF7F7F7);
}
