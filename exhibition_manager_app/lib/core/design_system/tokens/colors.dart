import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';

/// Muntajat HUB — Design Tokens: Colors
///
/// Two curated palettes served through one API:
///   • **Light — Modern Indigo:** a confident indigo signature on a clean, cool
///     near-white canvas. Airy, professional, contemporary.
///   • **Dark — Neutral Graphite:** a near-neutral graphite canvas where the
///     indigo accent is the single strong colour. Calm, premium, timeless.
///
/// Every value is a getter keyed on [AppThemeController.isDark], so switching the
/// mode and rebuilding recolours the whole app — no `Theme.of(context)` plumbing.
class AppColors {
  AppColors._();

  static bool get _d => AppThemeController.isDark;

  // ─── Brand ─────────────────────────────────────────────────
  static Color get primary => _d ? const Color(0xFF5A8FC4) : const Color(0xFF3A71B3);
  static Color get primaryLight => _d ? const Color(0xFF7BAAD4) : const Color(0xFF4A85C4);
  static Color get primaryDark => _d ? const Color(0xFF4A7FB4) : const Color(0xFF2A5F9B);
  static Color get primaryDeep => _d ? const Color(0xFF3A6FA4) : const Color(0xFF1E4D82);
  static Color get primaryContainer => _d ? const Color(0xFF1E2A3C) : const Color(0xFFE3EDF7);
  static Color get secondary => _d ? const Color(0xFF2A2C36) : const Color(0xFFEFF0FB);
  static Color get accent => _d ? const Color(0xFFE0B25A) : const Color(0xFFF5A524);
  static Color get accentDark => _d ? const Color(0xFFC89540) : const Color(0xFFD98A12);
  static Color get accentSoft => _d ? const Color(0xFF2E2A20) : const Color(0xFFFDECD0);

  // ─── Semantic ──────────────────────────────────────────────
  static Color get success => _d ? const Color(0xFF46C08A) : const Color(0xFF10B981);
  static Color get successLight => _d ? const Color(0xFF16241D) : const Color(0xFFE6F7F0);
  static Color get warning => _d ? const Color(0xFFD9A44E) : const Color(0xFFF59E0B);
  static Color get warningLight => _d ? const Color(0xFF2A2418) : const Color(0xFFFEF3C7);
  static Color get error => _d ? const Color(0xFFE88089) : const Color(0xFFEF4444);
  static Color get errorLight => _d ? const Color(0xFF2E1D1E) : const Color(0xFFFEE2E2);
  static Color get info => _d ? const Color(0xFF6D74F0) : const Color(0xFF3B82F6);
  static Color get infoLight => _d ? const Color(0xFF232A44) : const Color(0xFFDBEAFE);

  // ─── Surface & Background ──────────────────────────────────
  static Color get background => _d ? const Color(0xFF141519) : const Color(0xFFF6F7FB);
  static Color get surface => _d ? const Color(0xFF1D1F26) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => _d ? const Color(0xFF282B34) : const Color(0xFFF1F2F8);
  static Color get cardBackground => _d ? const Color(0xFF1D1F26) : const Color(0xFFFFFFFF);

  // ─── Text ──────────────────────────────────────────────────
  static Color get textPrimary => _d ? const Color(0xFFF2F3F6) : const Color(0xFF13141D);
  static Color get textSecondary => _d ? const Color(0xFF9CA0AC) : const Color(0xFF585C6C);
  static Color get textTertiary => _d ? const Color(0xFF6E727E) : const Color(0xFF9CA0AE);
  static Color get textOnPrimary => const Color(0xFFFFFFFF);
  static Color get textOnDark => const Color(0xFFFFFFFF);

  // ─── Border & Divider ──────────────────────────────────────
  static Color get border => _d ? const Color(0xFF2C2F39) : const Color(0xFFE7E9F2);
  static Color get borderLight => _d ? const Color(0xFF262932) : const Color(0xFFEEF0F7);
  static Color get divider => _d ? const Color(0xFF2C2F39) : const Color(0xFFE7E9F2);

  // ─── Status (badges) ───────────────────────────────────────
  static Color get statusNew => primary;
  static Color get statusShipped => warning;
  static Color get statusReceived => success;
  static Color get statusCompleted => _d ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get statusInProgress => warning;
  static Color get statusCancelled => error;

  // ─── Gradients ─────────────────────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryLight],
      );

  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, primaryLight],
      );

  /// Hero header gradient. Light: a rich single-hue indigo. Dark: a subtle
  /// graphite so white type + coloured accents read cleanly on top.
  static LinearGradient get heroGradient => _d
      ? const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF242734), Color(0xFF16171C)],
        )
      : const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1E4D82), Color(0xFF3A71B3), Color(0xFF4A85C4)],
          stops: [0.0, 0.55, 1.0],
        );

  /// Warm accent gradient for points / celebration.
  static LinearGradient get goldGradient => _d
      ? const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE0B25A), Color(0xFFC89540)],
        )
      : const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF5A524), Color(0xFFD98A12)],
        );

  /// Success gradient (streaks, completion).
  static LinearGradient get successGradient => _d
      ? const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF46C08A), Color(0xFF34D399)],
        )
      : const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF34D399), Color(0xFF10B981)],
        );

  // ─── Shimmer (skeletons) ───────────────────────────────────
  static Color get shimmerBase => _d ? const Color(0xFF242730) : const Color(0xFFE7E9F2);
  static Color get shimmerHighlight => _d ? const Color(0xFF2E313B) : const Color(0xFFF5F6FB);
}
