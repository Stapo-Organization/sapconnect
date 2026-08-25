import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Language + appearance, persisted. Both are *user* choices; neither is
/// derived from the account, so they survive sign-out.
@immutable
class AppSettings {
  const AppSettings({required this.themeMode, this.locale});

  final ThemeMode themeMode;

  /// `null` follows the device language.
  final Locale? locale;

  /// The locale actually in effect. Needed before `MaterialApp` resolves one,
  /// because the type family is chosen from it. Arabic is the product's
  /// primary language, so any unsupported device language lands on Arabic.
  Locale get effectiveLocale {
    final chosen = locale;
    if (chosen != null) return chosen;
    for (final deviceLocale in PlatformDispatcher.instance.locales) {
      if (deviceLocale.languageCode == 'ar' || deviceLocale.languageCode == 'en') {
        return Locale(deviceLocale.languageCode);
      }
    }
    return const Locale('ar');
  }

  String get languageCode => effectiveLocale.languageCode;

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale, bool clearLocale = false}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: clearLocale ? null : (locale ?? this.locale),
      );
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final store = ref.read(localStoreProvider);
    final code = store.localeCode;
    return AppSettings(
      themeMode: store.themeMode,
      locale: code == null ? null : Locale(code),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(localStoreProvider).setThemeMode(mode);
  }

  /// Switching language re-fetches the catalog: the server maps product ids
  /// through Polylang per `?lang=`, so cached Arabic payloads are wrong for
  /// English and vice versa.
  Future<void> setLocale(String? code) async {
    if (code == state.locale?.languageCode) return;
    state = state.copyWith(
      locale: code == null ? null : Locale(code),
      clearLocale: code == null,
    );
    await ref.read(localStoreProvider).setLocaleCode(code);
    await ref.read(apiClientProvider).clearCache();
    ref.invalidate(catalogRevisionProvider);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);
