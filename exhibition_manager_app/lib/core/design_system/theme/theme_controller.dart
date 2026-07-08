import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/storage/secure_storage.dart';

/// The three theme choices the user can pick.
enum AppThemeMode { system, light, dark }

/// App-wide light/dark controller — the single source of truth for which
/// palette [AppColors] serves.
///
/// Mirrors [AppLocalizations]'s pattern: a [ValueNotifier] the app root listens
/// to, persisted in [SecureStorage], and initialized before the first frame.
///
/// [AppColors] (and everything derived from it) reads [isDark] at build time, so
/// flipping [_dark] and rebuilding the tree recolours the entire app at once —
/// no need to route thousands of token reads through `Theme.of(context)`.
class AppThemeController {
  AppThemeController._();

  static const _storageKey = 'app_theme_mode';

  /// The user's choice (light / dark / follow-system). The app root listens.
  static final ValueNotifier<AppThemeMode> modeNotifier =
      ValueNotifier(AppThemeMode.system);

  static AppThemeMode get mode => modeNotifier.value;

  /// The *resolved* brightness the token getters read. Updated by the app root
  /// each build from the current [mode] + platform brightness.
  static bool _dark = false;
  static bool get isDark => _dark;

  /// Resolve the effective brightness from the chosen [mode] and the platform's
  /// current brightness (used only when [mode] is [AppThemeMode.system]).
  /// Returns whether the resolved value changed.
  static bool resolve(Brightness platformBrightness) {
    final next = switch (modeNotifier.value) {
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.system => platformBrightness == Brightness.dark,
    };
    final changed = next != _dark;
    _dark = next;
    return changed;
  }

  /// Load the saved choice before the first frame.
  static Future<void> initialize() async {
    final saved = await SecureStorage.read(_storageKey);
    modeNotifier.value = switch (saved) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }

  /// Persist and broadcast a new choice.
  static Future<void> setMode(AppThemeMode m) async {
    if (modeNotifier.value == m) return;
    modeNotifier.value = m;
    await SecureStorage.write(_storageKey, m.name);
  }
}
