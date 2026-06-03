import 'package:flutter/material.dart';

/// Muntajat Exhibition Manager — Design Tokens: Colors
///
/// Curated color palette for a premium warehouse management app.
/// Uses a deep blue primary with teal accents for a professional feel.
class AppColors {
  AppColors._();

  // ─── Brand Colors ──────────────────────────────────────────
  static const Color primary = Color(0xFF3A71B3);
  static const Color primaryLight = Color(0xFF6B9CDC);
  static const Color primaryDark = Color(0xFF1E4880);
  static const Color primaryDeep = Color(0xFF143966); // deepest navy for gradient hero
  static const Color primaryContainer = Color(0xFFE8F1FC); // soft blue tint surface
  static const Color secondary = Color(0xFFFFF7E6);
  static const Color accent = Color(0xFFF4BE2C);
  static const Color accentDark = Color(0xFFD99E0B);
  static const Color accentSoft = Color(0xFFFDF3D6);

  // ─── Semantic Colors ───────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ─── Surface & Background ──────────────────────────────────
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ─── Text Colors ───────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ─── Border & Divider ──────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  // ─── Status Colors (for badges) ────────────────────────────
  static const Color statusNew = Color(0xFF3A71B3);
  static const Color statusShipped = Color(0xFFF59E0B);
  static const Color statusReceived = Color(0xFF10B981);
  static const Color statusCompleted = Color(0xFF059669);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusCancelled = Color(0xFFEF4444);

  // ─── Gradient ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryLight],
  );

  /// Rich three-stop brand gradient for hero headers (deep navy → royal → light).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [primaryDeep, primary, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold gradient for points / level / celebration accents.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [accent, accentDark],
  );

  /// Subtle success gradient (streaks, completion).
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF34D399), success],
  );

  // ─── Shimmer ───────────────────────────────────────────────
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
}

