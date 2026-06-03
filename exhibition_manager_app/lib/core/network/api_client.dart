import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage/secure_storage.dart';

/// API Client — HTTP wrapper with auth token management
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  String? _token;

  /// Set auth token (called after login)
  void setToken(String token) {
    _token = token;
  }

  /// Clear auth token (called on logout)
  void clearToken() {
    _token = null;
  }

  /// Get current token
  String? get token => _token;

  /// Initialize from stored token
  Future<void> initFromStorage() async {
    _token = await SecureStorage.getToken();
  }

  /// Common headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// GET request
  Future<ApiResult> get(String url, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      debugPrint('🌐 GET $uri');
      final response = await _client.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ GET Error: $e');
      return ApiResult.error('خطأ في الاتصال: $e');
    }
  }

  /// POST request
  Future<ApiResult> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      debugPrint('🌐 POST $uri');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ POST Error: $e');
      return ApiResult.error('خطأ في الاتصال: $e');
    }
  }

  /// PUT request
  Future<ApiResult> put(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      debugPrint('🌐 PUT $uri');
      final response = await _client.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ PUT Error: $e');
      return ApiResult.error('خطأ في الاتصال: $e');
    }
  }

  /// DELETE request
  Future<ApiResult> delete(String url) async {
    try {
      final uri = Uri.parse(url);
      debugPrint('🌐 DELETE $uri');
      final response = await _client.delete(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ DELETE Error: $e');
      return ApiResult.error('خطأ في الاتصال: $e');
    }
  }

  /// Handle HTTP response
  ApiResult _handleResponse(http.Response response) {
    debugPrint('📥 Status: ${response.statusCode}');

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResult.success(body);
    }

    // Handle specific error codes
    switch (response.statusCode) {
      case 401:
        clearToken();
        SecureStorage.deleteToken();
        return ApiResult.error(
          body['message'] ?? 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.',
          statusCode: 401,
        );
      case 403:
        return ApiResult.error(
          body['message'] ?? 'غير مصرح لك بهذا الإجراء.',
          statusCode: 403,
        );
      case 404:
        return ApiResult.error(
          body['message'] ?? 'العنصر غير موجود.',
          statusCode: 404,
        );
      case 422:
        return ApiResult.error(
          body['message'] ?? 'بيانات غير صالحة.',
          statusCode: 422,
          errors: body['errors'],
        );
      default:
        return ApiResult.error(
          body['message'] ?? 'حدث خطأ غير متوقع.',
          statusCode: response.statusCode,
        );
    }
  }
}

/// API Result wrapper
class ApiResult {
  final bool isSuccess;
  final dynamic data;
  final String? errorMessage;
  final int? statusCode;
  final dynamic errors;

  ApiResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.errors,
  });

  factory ApiResult.success(dynamic data) => ApiResult._(
        isSuccess: true,
        data: data,
      );

  factory ApiResult.error(String message, {int? statusCode, dynamic errors}) =>
      ApiResult._(
        isSuccess: false,
        errorMessage: message,
        statusCode: statusCode,
        errors: errors,
      );

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
}
