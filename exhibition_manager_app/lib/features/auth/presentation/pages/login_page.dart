import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/owner_command/owner_routing.dart';

/// Login Page — Inspired by the Figma splash design with warm cream tones,
/// gold accents, exact Figma brand assets, and a back-to-home button.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repo = AuthRepository();

  // Figma-inspired palette
  // «المتجر»: the login follows the app — grey canvas, white card, ink actions.
  static Color get _creamBg => AppColors.background;
  static Color get _brandBlueDark => AppColors.textPrimary;


  // 0 = email + password, 1 = phone + OTP
  int _mode = 0;

  // Email mode
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Phone / OTP mode
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _switchMode(int mode) {
    if (mode == _mode) return;
    _resendTimer?.cancel();
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _otpSent = false;
      _otpController.clear();
      _resendSeconds = 0;
    });
  }

  void _goHome(User user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OwnerRouting.shellFor(user)),
      (route) => false,
    );
  }

  // ─── Email + password ──────────────────────────────────────
  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repo.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      _goHome(result.user!);
    } else {
      setState(() => _errorMessage = result.error ?? context.tr('unexpected_error'));
    }
  }

  // ─── Phone / OTP ───────────────────────────────────────────
  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      setState(() => _errorMessage = context.tr('mobile_required'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repo.requestOtp(mobile);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _otpSent = true);
      _startResendCountdown();
    } else {
      setState(() => _errorMessage = result.notRegistered
          ? context.tr('mobile_not_registered')
          : (result.error ?? context.tr('unexpected_error')));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repo.loginWithOtp(_mobileController.text.trim(), otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      _goHome(result.user!);
    } else {
      setState(() => _errorMessage = context.tr('otp_invalid'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBg,
      body: Stack(
        children: [
          // ─── Main Content ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ─── Top Bar with Back Button ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Scrollable Body ──────────────────────────────
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.base,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Logo Section (Figma assets) ──────────
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/logo_transparent.png',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Muntajat HUB',
                                  style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms).slideY(
                                begin: -0.05,
                                end: 0,
                                curve: Curves.easeOut,
                              ),
                          const SizedBox(height: AppSpacing.xxl),

                          // ─── Login Card ────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.borderXxl,
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.tr('login'),
                                  style: AppTypography.headlineSmall.copyWith(color: _brandBlueDark),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  context.tr('login_subtitle'),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // ─── Segmented Control ───────────────
                                _buildSegmentedControl(),
                                const SizedBox(height: AppSpacing.xl),

                                if (_mode == 0) _buildEmailMode() else _buildPhoneMode(),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(
                                begin: 0.06,
                                end: 0,
                                curve: Curves.easeOut,
                              ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Email / phone switch ──────────────────────────────────
  Widget _buildSegmentedControl() {
    return AppSegmentedControl(
      selectedIndex: _mode,
      onChanged: _switchMode,
      items: [
        SegmentItem(context.tr('login_with_email'), icon: Icons.email_outlined),
        SegmentItem(context.tr('login_with_phone'), icon: Icons.sms_outlined),
      ],
    );
  }

  // ─── Themed Input Decoration ───────────────────────────────
  InputDecoration _themedInput({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffix,
  }) {
    // Theme defaults (white field, grey stroke, blue focus ring).
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
    );
  }

  // ─── Themed Button ─────────────────────────────────────────
  Widget _themedButton({
    required String label,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return AppButton(label: label, icon: icon, onPressed: onPressed, loading: _isLoading);
  }

  // ─── Email mode UI ─────────────────────────────────────────
  Widget _buildEmailMode() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: _themedInput(
              label: context.tr('email'),
              hint: context.tr('email_hint'),
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return context.tr('email_required');
              }
              final emailRegex = RegExp(
                r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
              );
              if (!emailRegex.hasMatch(v.trim())) {
                return context.tr('email_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _loginEmail(),
            decoration: _themedInput(
              label: context.tr('password'),
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textTertiary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return context.tr('password_required');
              }
              return null;
            },
          ),
          _errorBox(),
          const SizedBox(height: AppSpacing.xl),
          _themedButton(
            label: context.tr('login'),
            onPressed: _isLoading ? null : _loginEmail,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }

  // ─── Phone / OTP mode UI ───────────────────────────────────
  Widget _buildPhoneMode() {
    if (!_otpSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('otp_login_hint'),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.base),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _themedInput(
              label: context.tr('mobile_number'),
              hint: context.tr('mobile_number_hint'),
              icon: Icons.phone_iphone_rounded,
            ),
            onSubmitted: (_) => _sendOtp(),
          ),
          _errorBox(),
          const SizedBox(height: AppSpacing.xl),
          _themedButton(
            label: context.tr('send_otp'),
            onPressed: _isLoading ? null : _sendOtp,
            icon: Icons.sms_rounded,
          ),
        ],
      );
    }

    // OTP entry
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            children: [
              TextSpan(text: '${context.tr('otp_sent_to')} '),
              TextSpan(
                text: _mobileController.text.trim(),
                style: AppTypography.bodySmall.copyWith(
                  color: _brandBlueDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 4,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTypography.headlineMedium.copyWith(
            color: _brandBlueDark,
            fontWeight: FontWeight.w700,
            letterSpacing: 16,
          ),
          decoration: const InputDecoration(counterText: '', hintText: '••••'),
          onChanged: (v) {
            if (v.length == 4 && !_isLoading) _verifyOtp();
          },
        ),
        _errorBox(),
        const SizedBox(height: AppSpacing.base),
        _themedButton(
          label: context.tr('verify'),
          onPressed: _isLoading ? null : _verifyOtp,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _resendTimer?.cancel();
                setState(() {
                  _otpSent = false;
                  _otpController.clear();
                  _errorMessage = null;
                  _resendSeconds = 0;
                });
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.link),
              child: Text(context.tr('change_number')),
            ),
            if (_resendSeconds > 0)
              Text(
                context.tr('resend_in').replaceAll('{s}', '$_resendSeconds'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: TextButton.styleFrom(foregroundColor: AppColors.link),
                child: Text(context.tr('resend_otp')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _errorBox() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.base),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
