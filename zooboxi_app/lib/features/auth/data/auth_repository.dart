import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';

/// The answer to `POST /auth/otp/send`.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.displayPhone,
    this.resendAfter = 60,
    this.expiresIn = 300,
  });

  /// The number as the server will show it back, e.g. "0512•••678".
  final String displayPhone;

  /// Seconds before "resend" becomes tappable.
  final int resendAfter;
  final int expiresIn;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        displayPhone: asString(json['display_phone']),
        resendAfter: asInt(json['resend_after'], fallback: 60),
        expiresIn: asInt(json['expires_in'], fallback: 300),
      );
}

/// The answer to `POST /auth/otp/verify`.
@immutable
class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
    this.isNew = false,
    this.cartMerged = false,
  });

  final String token;
  final ZbUser user;

  /// First sign-in: the flow continues into profile completion.
  final bool isNew;

  /// The guest basket was folded into the account's — worth telling them.
  final bool cartMerged;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: asString(json['token']),
        user: ZbUser.fromJson(asMap(json['user'])),
        isNew: asBool(json['is_new']),
        cartMerged: asBool(json['cart_merged']),
      );
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<OtpChallenge> sendOtp(String phone) async =>
      OtpChallenge.fromJson(asMap(await _api.post('/auth/otp/send', body: {'phone': phone})));

  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    required String platform,
    required String deviceName,
  }) async {
    final data = await _api.post('/auth/otp/verify', body: {
      'phone': phone,
      'otp': otp,
      'platform': platform,
      'device_name': deviceName,
    });
    return AuthResult.fromJson(asMap(data));
  }

  Future<ZbUser> updateProfile({String? name, String? email}) async {
    final data = await _api.patch('/me', body: {'name': ?name, 'email': ?email});
    final json = asMap(data);
    return ZbUser.fromJson(json.containsKey('user') ? asMap(json['user']) : json);
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

/// Saudi mobile numbers, in every shape a customer might type them.
/// Returns the canonical `05XXXXXXXX`, or null when it isn't one.
String? normalizeSaudiPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00966')) digits = digits.substring(5);
  if (digits.startsWith('966')) digits = digits.substring(3);
  if (digits.length == 9 && digits.startsWith('5')) digits = '0$digits';
  if (digits.length == 10 && digits.startsWith('05')) return digits;
  return null;
}
