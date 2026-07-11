import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/shadows.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/features/notifications/presentation/pages/notification_preferences_page.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/localization/language_switch_overlay.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/public/presentation/pages/public_landing_page.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';

/// Profile Page — User info, Language Switcher, and Logout (Bilingual & Premium Redesign)
class ProfilePage extends StatelessWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocalizations.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(context.tr('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(context.tr('logout_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                context.tr('cancel'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
              ),
              child: Text(context.tr('logout')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Blocking progress overlay so the (time-capped) server sign-out never
    // looks like a frozen screen.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.borderLg,
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );

    // One canonical sign-out path (device unregister + token revoke + local
    // clear) — capped internally so it always returns quickly.
    await AuthRepository().logout();

    if (context.mounted) {
      // Guests land on the public home, not the login form.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PublicLandingPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: context.tr('nav_profile'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ─── Avatar & User Card (Premium Gradient Backing) ────
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: AppDomain.profile.gradient,
                borderRadius: AppRadius.borderXxxl,
                boxShadow: AppShadows.glow(AppDomain.profile.accentDark, alpha: 0.28),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.accent, // Gold highlight
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: AppTypography.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    user.name,
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user.email,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ─── Language Switcher Card (Interactive Segmented) ──
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.borderLg,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language_rounded, color: AppDomain.profile.accent, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        context.tr('language'),
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Custom Segmented Toggle Buttons
                  Row(
                    children: [
                      // Arabic Toggle
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isArabic) animatedLanguageSwitch(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                            decoration: BoxDecoration(
                              color: isArabic ? AppDomain.profile.accent : AppColors.background,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                color: isArabic ? AppDomain.profile.accent : AppColors.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                context.tr('arabic'),
                                style: AppTypography.labelMedium.copyWith(
                                  color: isArabic ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // English Toggle
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isArabic) animatedLanguageSwitch(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                            decoration: BoxDecoration(
                              color: !isArabic ? AppDomain.profile.accent : AppColors.background,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                color: !isArabic ? AppDomain.profile.accent : AppColors.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                context.tr('english'),
                                style: AppTypography.labelMedium.copyWith(
                                  color: !isArabic ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.base),

            // ─── Appearance (Light / Dark / System) ─────────────
            ValueListenableBuilder<AppThemeMode>(
              valueListenable: AppThemeController.modeNotifier,
              builder: (context, mode, _) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.borderLg,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dark_mode_rounded,
                              color: AppDomain.profile.accent, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            context.tr('appearance'),
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSegmentedControl(
                        selectedIndex: mode.index,
                        onChanged: (i) =>
                            AppThemeController.setMode(AppThemeMode.values[i]),
                        activeColor: AppDomain.profile.accent,
                        items: [
                          SegmentItem(context.tr('theme_system'),
                              icon: Icons.brightness_auto_rounded),
                          SegmentItem(context.tr('theme_light'),
                              icon: Icons.light_mode_rounded),
                          SegmentItem(context.tr('theme_dark'),
                              icon: Icons.dark_mode_rounded),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.base),

            // ─── Notifications Preferences (tap → full screen) ──
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        color: AppDomain.profile.accent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('notifications_title'),
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.tr('notifications_subtitle'),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.base),

            // ─── Info tiles ──────────────────────────────
            if (user.mobileNumber != null)
              _InfoTile(
                icon: Icons.phone_outlined,
                title: context.tr('phone'),
                value: user.mobileNumber!,
              ),
            _InfoTile(
              icon: Icons.warehouse_outlined,
              title: context.tr('warehouses'),
              value: user.warehouseCodes.isNotEmpty ? user.warehouseCodes.join(' • ') : '—',
              index: 1,
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              title: context.tr('roles'),
              value: user.roles.isNotEmpty ? user.roles.join(' • ') : '—',
              index: 2,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ─── System Info Footer ──────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.borderLg,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Text(
                    context.tr('system_title'),
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${context.tr('version')} 1.0.0',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ─── Logout Button ───────────────────────────
            AppButton(
              label: context.tr('logout'),
              onPressed: () => _logout(context),
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.outline,
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  /// Position in the tile list — staggers the icon chip's pop-in wave.
  final int index;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          PopIn(
            delay: Duration(milliseconds: 60 * index.clamp(0, 10)),
            child: GlowIconChip(
              icon: icon,
              color: AppDomain.profile.accent,
              size: 32,
              iconSize: 18,
              borderRadius: AppRadius.borderMd,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
