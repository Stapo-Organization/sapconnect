import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import 'widgets/otp_step.dart';
import 'widgets/phone_step.dart';
import 'widgets/welcome_step.dart';

/// Opens the sign-in sheet. Resolves `true` once there is a signed-in
/// customer, `false` if the sheet was dismissed.
///
/// This is the app's *only* auth entry point: nothing navigates to a login
/// screen, because browsing is never gated. Sign-in is asked for at the exact
/// moment it becomes necessary — hearting a product, opening orders,
/// checking out — and the action continues afterwards.
Future<bool> showAuthSheet(BuildContext context, {String? reason}) async {
  final result = await showZbSheet<bool>(
    context,
    builder: (_) => AuthSheet(reason: reason),
  );
  return result ?? false;
}

enum _Step { phone, otp, welcome }

class AuthSheet extends ConsumerStatefulWidget {
  const AuthSheet({super.key, this.reason});

  /// Why we're asking, e.g. "sign in to save your favourites".
  final String? reason;

  @override
  ConsumerState<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<AuthSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  bool _otpError = false;

  String _phone = '';
  String _displayPhone = '';
  bool _cartMerged = false;

  Timer? _countdown;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _countdown?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _secondsLeft = seconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _sendOtp({bool resend = false}) async {
    final l = L.of(context);
    final normalized = normalizeSaudiPhone(_phoneController.text);
    if (normalized == null) {
      setState(() => _error = l.authPhoneInvalid);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final challenge = await ref.read(authRepositoryProvider).sendOtp(normalized);
      if (!mounted) return;
      setState(() {
        _phone = normalized;
        _displayPhone = challenge.displayPhone.isEmpty ? normalized : challenge.displayPhone;
        _step = _Step.otp;
        _busy = false;
        if (resend) _otpController.clear();
        _otpError = false;
      });
      _startCountdown(challenge.resendAfter);
      Haptics.light();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessage(context, e);
      });
    }
  }

  Future<void> _verify(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _otpError = false;
    });

    try {
      final result = await ref.read(authRepositoryProvider).verifyOtp(
            phone: _phone,
            otp: code,
            platform: _platform(),
            deviceName: _deviceName(),
          );
      await ref.read(sessionProvider.notifier).establish(
            token: result.token,
            user: result.user,
          );
      if (!mounted) return;

      _countdown?.cancel();
      await Haptics.success();
      if (!mounted) return;

      _cartMerged = result.cartMerged;
      if (result.isNew) {
        setState(() {
          _step = _Step.welcome;
          _busy = false;
          _nameController.text = result.user.name;
          _emailController.text = result.user.email ?? '';
        });
        return;
      }
      _finish();
    } catch (e) {
      if (!mounted) return;
      Haptics.warning();
      setState(() {
        _busy = false;
        _otpError = true;
        _error = errorMessage(context, e);
      });
      _otpController.clear();
    }
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            name: name.isEmpty ? null : name,
            email: email.isEmpty ? null : email,
          );
      ref.read(sessionProvider.notifier).applyUser(user);
    } catch (_) {
      // A missing display name is not worth blocking someone's first order.
    }
    if (!mounted) return;
    _finish();
  }

  void _finish() {
    final l = L.of(context);
    final merged = _cartMerged;
    // Captured *before* the pop: this sheet's own context is dead afterwards,
    // and the toast has to outlive it.
    final root = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop(true);
    AppToast.success(root, merged ? l.authCartMerged : l.authLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    final (title, subtitle) = switch (_step) {
      _Step.phone => (l.authTitle, widget.reason ?? l.authSubtitle),
      _Step.otp => (l.authOtpTitle, l.authOtpSubtitle(_displayPhone)),
      _Step.welcome => (l.authWelcomeTitle, l.authWelcomeSubtitle),
    };

    return BottomSheetScaffold(
      title: title,
      subtitle: subtitle,
      child: switch (_step) {
        _Step.phone => PhoneStep(
            controller: _phoneController,
            busy: _busy,
            error: _error,
            onSubmit: _sendOtp,
          ),
        _Step.otp => OtpStep(
            controller: _otpController,
            busy: _busy,
            error: _error,
            hasError: _otpError,
            secondsLeft: _secondsLeft,
            onCompleted: _verify,
            onResend: () => _sendOtp(resend: true),
            onChangeNumber: () => setState(() {
              _countdown?.cancel();
              _step = _Step.phone;
              _otpController.clear();
              _error = null;
              _otpError = false;
            }),
          ),
        _Step.welcome => WelcomeStep(
            nameController: _nameController,
            emailController: _emailController,
            busy: _busy,
            onSubmit: _completeProfile,
          ),
      },
    );
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  static String _deviceName() {
    if (kIsWeb) return 'Web';
    return Platform.operatingSystemVersion.split('(').first.trim();
  }
}
