import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keychain/Keystore-backed storage for the two values that must not sit in
/// SharedPreferences: the bearer token and the device's guest id.
class SecureStore {
  const SecureStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kToken = 'zb_auth_token';
  static const _kGuestId = 'zb_guest_id';

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _kToken);
    } catch (_) {
      // A corrupt keystore entry must not brick the app: treat it as signed out.
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _kToken, value: token);
    } catch (_) {}
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _kToken);
    } catch (_) {}
  }

  /// The stable per-device id sent as `X-ZB-Guest`. It keys the server-side
  /// guest cart, so it is generated once and kept for the install's lifetime.
  Future<String> guestId() async {
    try {
      final existing = await _storage.read(key: _kGuestId);
      if (existing != null && existing.isNotEmpty) return existing;
    } catch (_) {}
    final fresh = const Uuid().v4();
    try {
      await _storage.write(key: _kGuestId, value: fresh);
    } catch (_) {}
    return fresh;
  }

  /// iOS keeps Keychain items across an app *delete*, so a reinstall would
  /// resume a stranger's session on a resold or restored device. A marker file
  /// in the app sandbox (which reinstalling does wipe) tells the two apart:
  /// no marker means this is a genuinely fresh install, so drop the token.
  ///
  /// Returns true when a stale session was cleared.
  Future<bool> clearOnFreshInstall() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final marker = File('${dir.path}/.zb_installed');
      if (marker.existsSync()) return false;
      await clearToken();
      marker.createSync(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
