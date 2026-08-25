import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local state: preferences, the catalog payload/ETag cache,
/// recently-viewed products, recent searches, the persisted delivery location
/// and the pending analytics batch.
///
/// Tokens and the guest id never live here — see `SecureStore`.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'settings.theme_mode';
  static const _kLocale = 'settings.locale';
  static const _kOnboarded = 'settings.onboarded';
  static const _kLocation = 'location.current';
  static const _kRecentIds = 'catalog.recent_ids';
  static const _kRecentSearches = 'catalog.recent_searches';
  static const _kEvents = 'analytics.pending';
  static const _kCachePrefix = 'cache.';
  static const _kEtagPrefix = 'etag.';

  static const int maxRecentlyViewed = 12;
  static const int _maxRecentSearches = 8;
  static const int _maxPendingEvents = 200;

  // ── Settings ─────────────────────────────────────────────────────────

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(_kThemeMode, mode.name);

  /// `null` means "follow the device language" — which resolves to Arabic
  /// whenever the device isn't set to a language the app speaks.
  String? get localeCode {
    final v = _prefs.getString(_kLocale);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setLocaleCode(String? code) =>
      code == null ? _prefs.remove(_kLocale) : _prefs.setString(_kLocale, code);

  bool get hasOnboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  // ── Delivery location ────────────────────────────────────────────────

  Map<String, dynamic>? get location {
    final raw = _prefs.getString(_kLocation);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLocation(Map<String, dynamic>? value) => value == null
      ? _prefs.remove(_kLocation)
      : _prefs.setString(_kLocation, jsonEncode(value));

  // ── Recently viewed ──────────────────────────────────────────────────

  List<int> get recentlyViewed =>
      (_prefs.getStringList(_kRecentIds) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();

  Future<void> pushRecentlyViewed(int productId) async {
    final ids = recentlyViewed..removeWhere((e) => e == productId);
    ids.insert(0, productId);
    await _prefs.setStringList(
      _kRecentIds,
      ids.take(maxRecentlyViewed).map((e) => '$e').toList(),
    );
  }

  // ── Recent searches ──────────────────────────────────────────────────

  List<String> get recentSearches => _prefs.getStringList(_kRecentSearches) ?? const [];

  Future<void> pushRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = recentSearches.toList()
      ..removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    await _prefs.setStringList(_kRecentSearches, list.take(_maxRecentSearches).toList());
  }

  Future<void> clearRecentSearches() => _prefs.remove(_kRecentSearches);

  // ── Analytics batch (survives a cold kill) ───────────────────────────

  List<Map<String, dynamic>> get pendingEvents {
    final raw = _prefs.getStringList(_kEvents) ?? const [];
    return raw
        .map((e) {
          try {
            final decoded = jsonDecode(e);
            return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> setPendingEvents(List<Map<String, dynamic>> events) => _prefs.setStringList(
        _kEvents,
        events.take(_maxPendingEvents).map(jsonEncode).toList(),
      );

  // ── HTTP payload + ETag cache ────────────────────────────────────────

  String? cachedBody(String key) => _prefs.getString('$_kCachePrefix$key');
  String? cachedEtag(String key) => _prefs.getString('$_kEtagPrefix$key');

  Future<void> putCached(String key, String etag, String body) async {
    await _prefs.setString('$_kEtagPrefix$key', etag);
    await _prefs.setString('$_kCachePrefix$key', body);
  }

  /// Dropped whenever the delivery location changes — every cached catalog
  /// payload is location-scoped, so keeping it would show another city's stock.
  Future<void> clearHttpCache() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_kCachePrefix) || k.startsWith(_kEtagPrefix))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
