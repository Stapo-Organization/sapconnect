import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
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
  static const _creamBg = Color(0xFFF8EDDF);
  static const _gold = Color(0xFFE4C88B);
  static const _goldDark = Color(0xFFC9A55E);
  static const _brandBlue = Color(0xFF3B6B9B);
  static const _brandBlueDark = Color(0xFF2A4F73);


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
          // ─── Subtle Watermark Background ─────────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.35,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tileSize = 200.0;
                    final cols = (constraints.maxWidth / tileSize).ceil() + 1;
                    final rows = (constraints.maxHeight / tileSize).ceil() + 1;
                    return Stack(
                      children: [
                        for (int r = 0; r < rows; r++)
                          for (int c = 0; c < cols; c++)
                            Positioned(
                              left: c * tileSize,
                              top: r * tileSize,
                              child: SvgPicture.asset(
                                'assets/svgs/splash_bg_pattern.svg',
                                width: tileSize,
                                height: tileSize,
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

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
                          color: _brandBlue,
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                // Heart Logo (Figma node 1-13597)
                                Image.asset(
                                  'assets/images/logo_transparent.png',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                // "Muntajat" English (Figma node 1-13708)
                                Text(
                                  'Muntajat',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFF4BE2C),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // "منتجات" SVG (Figma node 1-13709)
                                SvgPicture.asset(
                                  'assets/svgs/logo.svg',
                                  height: 22,
                                  fit: BoxFit.contain,
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
                              color: Colors.white,
                              borderRadius: AppRadius.borderXxxl,
                              border: Border.all(
                                color: _gold.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _goldDark.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.tr('login'),
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: _brandBlueDark,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  // ─── Custom Segmented Control (Figma-inspired) ─────────────
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _creamBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segmentTab(0, context.tr('login_with_email'), Icons.email_outlined),
          const SizedBox(width: 4),
          _segmentTab(1, context.tr('login_with_phone'), Icons.sms_outlined),
        ],
      ),
    );
  }

  Widget _segmentTab(int index, String label, IconData icon) {
    final selected = _mode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _goldDark.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? _brandBlue : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected ? _brandBlue : AppColors.textTertiary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Themed Input Decoration ───────────────────────────────
  InputDecoration _themedInput({
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _brandBlue.withValues(alpha: 0.6)),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.base,
      ),
      filled: true,
      fillColor: _creamBg.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _brandBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
    );
  }

  // ─── Themed Button ─────────────────────────────────────────
  Widget _themedButton({
    required String label,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _brandBlue.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
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
            fontWeight: FontWeight.w800,
            letterSpacing: 16,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            filled: true,
            fillColor: _creamBg.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _gold.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _gold.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _brandBlue, width: 1.5),
            ),
          ),
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
              style: TextButton.styleFrom(foregroundColor: _brandBlue),
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
                style: TextButton.styleFrom(foregroundColor: _goldDark),
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
