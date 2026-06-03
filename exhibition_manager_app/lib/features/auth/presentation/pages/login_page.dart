import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_logo.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/home/presentation/pages/main_shell.dart';

/// Login Page — Email + Password authentication with Localization
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = AuthRepository();
    final result = await repo.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success && result.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(user: result.user!)),
      );
    } else {
      setState(() => _errorMessage = result.error ?? context.tr('unexpected_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // ─── Logo Section ───────────────────────────────
                const Center(
                  child: MuntajatLogo(
                    size: 84,
                    showText: true,
                    fontSize: 28,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ─── Main Form Card ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.borderXxl,
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr('login'),
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textPrimary,
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

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.tr('email'),
                            hintText: context.tr('email_hint'),
                            prefixIcon: const Icon(Icons.email_outlined),
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.base),
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

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: context.tr('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.base),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textTertiary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return context.tr('password_required');
                            }
                            return null;
                          },
                        ),
                        
                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.base),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: AppRadius.borderMd,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
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
                        ],

                        const SizedBox(height: AppSpacing.xl),

                        // Login button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderMd,
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  context.tr('login'),
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
