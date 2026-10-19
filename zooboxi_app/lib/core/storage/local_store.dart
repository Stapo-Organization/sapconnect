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
  static const _kWelcomeSeen = 'settings.onboarded.v2';
  static const _kLocation = 'location.current';
  static const _kDriftDismissed = 'location.drift_dismissed';
  static const _kPendingAddress = 'address.pending';
  static const _kHousehold = 'pets.household.v1';
  static const _kShopsForOthers = 'pets.shops_for_others';
  static const _kShoppingFor = 'pets.shopping_for';
  static const _kHouseholdWelcomed = 'pets.welcomed';
  static const _kTrackingPrimed = 'analytics.tracking_primed';
  static const _kWeightNudgePrefix = 'pets.weight_nudge.';
  static const _kHouseholdInvite = 'pets.invite_dismissed';
  static const _kPetLifePrefix = 'pets.life.';
  static const _kSplashCompanion = 'splash.companion';
  static const _kRecentIds = 'catalog.recent_ids';
  static const _kRecentSearches = 'catalog.recent_searches';
  static const _kHomeCache = 'catalog.home_cache';
  static const _kHomeCachePrefix = 'catalog.home_cache.';
  static const _kShelf = 'shelf.selected';
  static const _kHomeFeedCache = 'catalog.home_feed_cache';
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

  /// Whether the welcome journey has run. Deliberately a *new* key: the old
  /// `settings.onboarded` only ever marked the location primer, and every
  /// existing install is owed the rebuilt journey once.
  bool get hasSeenWelcome => _prefs.getBool(_kWelcomeSeen) ?? false;
  Future<void> setWelcomeSeen() => _prefs.setBool(_kWelcomeSeen, true);

  // ── Delivery location ────────────────────────────────────────────────

  Map<String, dynamic>? get location => _json(_kLocation);

  /// The last "you're somewhere new" offer the customer waved away:
  /// `{lat, lng, at}`. The same spot isn't offered again for a day.
  Map<String, dynamic>? get driftDismissed => _json(_kDriftDismissed);
  Future<void> setDriftDismissed(Map<String, dynamic>? value) => value == null
      ? _prefs.remove(_kDriftDismissed)
      : _prefs.setString(_kDriftDismissed, jsonEncode(value));

  Future<void> setLocation(Map<String, dynamic>? value) => value == null
      ? _prefs.remove(_kLocation)
      : _prefs.setString(_kLocation, jsonEncode(value));

  /// An address a guest pinned during the welcome journey, waiting for the
  /// checkout that can finally attach a name and a phone to it. Cleared the
  /// moment it lands in the book or on an order — never carried into a second.
  Map<String, dynamic>? get pendingAddress => _json(_kPendingAddress);

  Future<void> setPendingAddress(Map<String, dynamic>? json) => json == null
      ? _prefs.remove(_kPendingAddress)
      : _prefs.setString(_kPendingAddress, jsonEncode(json));

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

  // ── Home payload cache (stale-while-revalidate) ──────────────────────
  //
  // Separate from the ETag store below: that one only spares the *bytes* on a
  // 304 and still needs a round trip. This one is what paints the storefront
  // on the frame the app opens, while the refresh happens behind it.

  /// Yesterday's storefront for one shelf.
  ///
  /// A slot per shelf, not one shared slot: with a single slot, crossing the
  /// tabs always landed on an empty cache and the other storefront started
  /// from a shimmer every single time — which is most of what «التبديل بطيء»
  /// actually was.
  ///
  /// The slot name is the shelf the payload DESCRIBES, never the one that was
  /// asked for. Those differ after closing hours, and filing a زوبكسي body
  /// under 'express' is how a full-store catalogue ends up painted in ember
  /// with a two-hour promise over it.
  Map<String, dynamic>? homeCacheFor(String shelf) {
    final slot = _json('$_kHomeCachePrefix$shelf');
    final data = slot?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);

    // One-time bridge from the single-slot build. Its stamp recorded the
    // REQUEST, so it cannot be trusted; the payload's own `scope.shelf` is
    // the only honest answer, and an entry that cannot prove which shelf it
    // describes is dropped. One shimmer, once, beats one wrong promise.
    final legacy = _json(_kHomeCache);
    final legacyData = legacy?['data'];
    if (legacyData is! Map) return null;
    final scope = legacyData['scope'];
    final described = scope is Map ? scope['shelf'] : null;
    if (described is! String || described != shelf) return null;
    return Map<String, dynamic>.from(legacyData);
  }

  Future<void> setHomeCache(Map<String, dynamic> json, {required String shelf}) =>
      _prefs.setString('$_kHomeCachePrefix$shelf', jsonEncode({'data': json}));

  // ── Storefront tab ───────────────────────────────────────────────────

  /// The shelf the customer last chose ('express' | 'all'), null on first run.
  String? get shelf => _prefs.getString(_kShelf);

  Future<void> setShelf(String value) => _prefs.setString(_kShelf, value);

  /// The feed is per-customer, so the sign-in state it was captured under is
  /// stored with it — one person's "buy again" must never flash on another's
  /// screen after a sign-out.
  ({bool authed, Map<String, dynamic> data})? get homeFeedCache {
    final wrapper = _json(_kHomeFeedCache);
    if (wrapper == null) return null;
    final data = wrapper['data'];
    if (data is! Map) return null;
    return (authed: wrapper['authed'] == true, data: Map<String, dynamic>.from(data));
  }

  Future<void> setHomeFeedCache(Map<String, dynamic> json, {required bool authed}) =>
      _prefs.setString(_kHomeFeedCache, jsonEncode({'authed': authed, 'data': json}));

  Map<String, dynamic>? _json(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  // ── Splash ───────────────────────────────────────────────────────────

  /// Who greets the customer on the next cold start: the animal the app
  /// speaks to (`cast` = a drawn cast member, `name` as the customer wrote
  /// it). Written whenever the household is known for certain and read
  /// synchronously by the splash, which never waits on the network. Null
  /// means nobody — the splash then plays the brand's own burst.
  Map<String, String>? get splashCompanion {
    final raw = _prefs.getString(_kSplashCompanion);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return {for (final e in decoded.entries) if (e.value is String) '${e.key}': e.value as String};
    } catch (_) {
      return null;
    }
  }

  Future<void> setSplashCompanion(Map<String, String>? value) =>
      value == null ? _prefs.remove(_kSplashCompanion) : _prefs.setString(_kSplashCompanion, jsonEncode(value));

  // ── «مين معك في البيت؟» ─────────────────────────────────────────────

  /// A guest's household as they described it in the welcome journey — the
  /// animals, by species, with whatever names they gave. Created on the
  /// server at sign-in, then cleared.
  List<Map<String, dynamic>> get household {
    final raw = _prefs.getString(_kHousehold);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final m in decoded) if (m is Map) Map<String, dynamic>.from(m)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setHousehold(List<Map<String, dynamic>> members) =>
      members.isEmpty ? _prefs.remove(_kHousehold) : _prefs.setString(_kHousehold, jsonEncode(members));

  /// «أتسوّق لغيري» — shopping for someone else's animal, or none at home yet.
  bool get shopsForOthers => _prefs.getBool(_kShopsForOthers) ?? false;
  Future<void> setShopsForOthers(bool value) => _prefs.setBool(_kShopsForOthers, value);

  /// Which animal the store is arranged for («تسوّق لـ»): a member key, or
  /// null for all of them.
  String? get shoppingFor => _prefs.getString(_kShoppingFor);
  Future<void> setShoppingFor(String? key) =>
      key == null ? _prefs.remove(_kShoppingFor) : _prefs.setString(_kShoppingFor, key);

  /// «ما أعرف الحين» on a pet's weight: when it was said, so the ask rests.
  DateTime? weightNudgeDismissed(int petId) {
    final ms = _prefs.getInt('$_kWeightNudgePrefix$petId');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> dismissWeightNudge(int petId) =>
      _prefs.setInt('$_kWeightNudgePrefix$petId', DateTime.now().millisecondsSinceEpoch);

  /// A pet's life stage as its owner answered it on a listing («كم عمر
  /// مشمش؟»): `young` | `adult` | `senior`. Keyed by household member key,
  /// used only when the pet has no birth date on the server.
  String? petLifeStage(String memberKey) => _prefs.getString('$_kPetLifePrefix$memberKey');

  Future<void> setPetLifeStage(String memberKey, String value) =>
      _prefs.setString('$_kPetLifePrefix$memberKey', value);

  /// «ليس الآن» on the home's «مين معك في البيت؟» card.
  DateTime? get householdInviteDismissed {
    final ms = _prefs.getInt(_kHouseholdInvite);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> dismissHouseholdInvite() => _prefs.setInt(_kHouseholdInvite, DateTime.now().millisecondsSinceEpoch);

  /// The one-time «رتّبنا الرئيسية على مقاس…» card has been seen.
  bool get householdWelcomed => _prefs.getBool(_kHouseholdWelcomed) ?? false;
  Future<void> setHouseholdWelcomed() => _prefs.setBool(_kHouseholdWelcomed, true);

  /// The tracking primer has been shown (whatever the answer): it never asks twice.
  bool get trackingPrimed => _prefs.getBool(_kTrackingPrimed) ?? false;
  Future<void> setTrackingPrimed() => _prefs.setBool(_kTrackingPrimed, true);

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
  /// The home snapshots go with them for exactly the same reason.
  Future<void> clearHttpCache() async {
    final keys = _prefs
        .getKeys()
        .where((k) =>
            k.startsWith(_kCachePrefix) ||
            k.startsWith(_kEtagPrefix) ||
            k.startsWith(_kHomeCachePrefix))
        .toList()
      ..addAll([_kHomeCache, _kHomeFeedCache]);
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
