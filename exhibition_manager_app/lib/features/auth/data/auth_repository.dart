import 'dart:async';

import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
import 'package:exhibition_manager_app/core/notifications/push_service.dart';
import 'package:exhibition_manager_app/core/permissions/app_session.dart';
import 'package:exhibition_manager_app/core/storage/secure_storage.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';

/// Authentication repository
class AuthRepository {
  final ApiClient _api = ApiClient();

  /// Login with email and password
  Future<({bool success, String? error, User? user, String? token})> login(
      String email, String password) async {
    final result = await _api.post(ApiEndpoints.login, body: {
      'email': email,
      'password': password,
    });

    if (result.isSuccess) {
      return _bootstrapSession(result.data);
    }

    return (success: false, error: result.errorMessage, user: null, token: null);
  }

  /// Request a one-time code be sent over SMS for passwordless login.
  ///
  /// The user must already have a registered mobile number on the backend; if
  /// not, the server replies 404 and [notRegistered] is set so the UI can show
  /// a friendly "contact admin" message.
  Future<({bool success, String? error, bool notRegistered})> requestOtp(
      String mobile) async {
    final result = await _api.post(ApiEndpoints.login, body: {
      'mobile_number': mobile,
    });

    if (result.isSuccess) {
      return (success: true, error: null, notRegistered: false);
    }

    return (
      success: false,
      error: result.errorMessage,
      notRegistered: result.statusCode == 404,
    );
  }

  /// Verify an SMS code and sign in. Shares the exact session bootstrap as
  /// [login] (token storage, global session, push registration).
  Future<({bool success, String? error, User? user, String? token})>
      loginWithOtp(String mobile, String otp) async {
    final result = await _api.post(ApiEndpoints.verifyOtp, body: {
      'mobile_number': mobile,
      'otp': otp,
    });

    if (result.isSuccess) {
      return _bootstrapSession(result.data);
    }

    return (success: false, error: result.errorMessage, user: null, token: null);
  }

  /// Persist the issued token + user, publish the global session and register
  /// the device for push. Shared by every successful sign-in path.
  Future<({bool success, String? error, User? user, String? token})>
      _bootstrapSession(dynamic data) async {
    final token = data['token'] as String;
    final user = User.fromJson(data['user']);

    await SecureStorage.saveToken(token);
    await SecureStorage.saveUserData(data['user']);

    _api.setToken(token);
    AppSession.set(user);

    // Register this device for push (non-blocking; prompts for permission on iOS).
    unawaited(PushService.instance.registerToken());

    return (success: true, error: null, user: user, token: token);
  }

  /// Logout — local sign-out is guaranteed and fast; the server-side cleanup
  /// (device unregister + token revoke) is best-effort with a hard time cap so
  /// a slow network can never hold the user on the screen.
  Future<void> logout() async {
    try {
      await () async {
        // Drop this device server-side BEFORE the auth token is invalidated.
        await PushService.instance.unregisterToken();
        await _api.post(ApiEndpoints.logout);
      }()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline / timeout — proceed with the local sign-out regardless.
    }
    _api.clearToken();
    AppSession.clear();
    // Only the session is cleared — language & theme preferences survive.
    await SecureStorage.clearAuth();
  }

  /// Check if user is logged in (from stored token)
  Future<User?> getCurrentUser() async {
    final token = await SecureStorage.getToken();
    if (token == null) return null;

    _api.setToken(token);

    // Verify token with server
    final result = await _api.get(ApiEndpoints.profile);
    if (result.isSuccess) {
      final user = User.fromJson(result.data['data'] ?? result.data);
      AppSession.set(user); // refresh abilities each session restore

      // Re-register this device for push on each session restore.
      unawaited(PushService.instance.registerToken());

      return user;
    }

    // Token invalid
    await SecureStorage.clearAll();
    _api.clearToken();
    return null;
  }
}
