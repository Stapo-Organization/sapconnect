import 'package:flutter/material.dart';

/// Muntajat Exhibition Manager — Design Tokens: Shadows
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get xl => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Soft "floating card" elevation used by the modern component kit.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Colored glow used under primary CTAs / hero headers.
  static List<BoxShadow> glow(Color color, {double alpha = 0.30}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
