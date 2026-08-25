/// Transport-and-contract error taxonomy. Screens switch on [ApiErrorType];
/// they never inspect status codes directly.
enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  cancelled,
  unknown,
}

/// A failed API call, already carrying the server's bilingual message when the
/// `{ok:false, error:{code, message_ar, message_en}}` envelope supplied one.
///
/// The app shows [messageFor] — the server's own wording in the active
/// language — and falls back to a localized generic message per [type] when
/// the server said nothing useful.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    this.code,
    this.messageAr,
    this.messageEn,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final ApiErrorType type;

  /// Machine-readable server code, e.g. `otp_invalid`, `cart_capped`.
  final String? code;

  final String? messageAr;
  final String? messageEn;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isAuthError => type == ApiErrorType.unauthorized;

  /// The server's message in [languageCode], or null when it sent none.
  String? messageFor(String languageCode) {
    final preferred = languageCode == 'ar' ? messageAr : messageEn;
    final value = preferred ?? messageAr ?? messageEn;
    return (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  String? get firstFieldError =>
      fieldErrors.isEmpty ? null : fieldErrors.values.first;

  @override
  String toString() => 'ApiException($type, $statusCode, $code)';
}
