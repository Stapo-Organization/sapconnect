import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_exception.dart';

/// Turns any thrown object into a sentence a customer can act on.
///
/// The server's own bilingual message wins when it sent one — it knows *why*
/// (`the last unit just sold`, `that coupon expired`) in a way a generic
/// network message never could. Only when it said nothing do we fall back to
/// a localized message for the error class.
String errorMessage(BuildContext context, Object? error) {
  final l = L.of(context);
  final locale = Localizations.localeOf(context).languageCode;

  if (error is ApiException) {
    final serverMessage = error.messageFor(locale);
    if (serverMessage != null) return serverMessage;
    return switch (error.type) {
      ApiErrorType.network => l.errNetwork,
      ApiErrorType.timeout => l.errTimeout,
      ApiErrorType.unauthorized => l.errUnauthorized,
      ApiErrorType.forbidden => l.errUnauthorized,
      ApiErrorType.notFound => l.errNotFound,
      ApiErrorType.validation => error.firstFieldError ?? l.errValidation,
      ApiErrorType.server => l.errServer,
      ApiErrorType.cancelled => l.errUnknown,
      ApiErrorType.unknown => l.errUnknown,
    };
  }
  return l.errUnknown;
}

/// True for errors where "check your connection" is the right framing, which
/// changes the illustration the error state shows.
bool isConnectivityError(Object? error) =>
    error is ApiException &&
    (error.type == ApiErrorType.network || error.type == ApiErrorType.timeout);
