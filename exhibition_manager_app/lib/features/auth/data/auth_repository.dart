import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';
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
      final token = result.data['token'] as String;
      final user = User.fromJson(result.data['user']);

      // Save to secure storage
      await SecureStorage.saveToken(token);
      await SecureStorage.saveUserData(result.data['user']);

      // Set token in API client
      _api.setToken(token);

      return (success: true, error: null, user: user, token: token);
    }

    return (success: false, error: result.errorMessage, user: null, token: null);
  }

  /// Logout
  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout);
    _api.clearToken();
    await SecureStorage.clearAll();
  }

  /// Check if user is logged in (from stored token)
  Future<User?> getCurrentUser() async {
    final token = await SecureStorage.getToken();
    if (token == null) return null;

    _api.setToken(token);

    // Verify token with server
    final result = await _api.get(ApiEndpoints.profile);
    if (result.isSuccess) {
      return User.fromJson(result.data['data'] ?? result.data);
    }

    // Token invalid
    await SecureStorage.clearAll();
    _api.clearToken();
    return null;
  }
}
