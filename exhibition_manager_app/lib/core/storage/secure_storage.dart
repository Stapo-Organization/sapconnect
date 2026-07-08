import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Secure storage for sensitive data (auth tokens, user info)
class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';

  // ─── Token ─────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ─── User Data ─────────────────────────────────────────────
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _userKey, value: jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: _userKey);
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  static Future<void> deleteUserData() async {
    await _storage.delete(key: _userKey);
  }

  // ─── Generic Key-Value ─────────────────────────────────────
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  // ─── Clear Auth ────────────────────────────────────────────
  /// Remove only the session (token + user) — language and theme preferences
  /// stay, so logging out doesn't reset the user's language.
  static Future<void> clearAuth() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  // ─── Clear All ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

