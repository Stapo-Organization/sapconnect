import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/features/notifications/presentation/pages/notification_preferences_page.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/localization/language_switch_overlay.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/auth/data/auth_repository.dart';
import 'package:exhibition_manager_app/features/public/presentation/pages/public_landing_page.dart';

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
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            PageHeader(title: context.tr('nav_profile')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Identity ────────────────────────────────
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0] : '?',
                            style: AppTypography.headlineSmall.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary)),
                              Text(user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ─── Settings ────────────────────────────────
                  AppSection(
                    title: context.tr('profile_settings'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _settingLabel(Icons.language_rounded, context.tr('language')),
                            const SizedBox(height: AppSpacing.sm),
                            AppSegmentedControl(
                              selectedIndex: isArabic ? 0 : 1,
                              onChanged: (i) {
                                if ((i == 0) != isArabic) animatedLanguageSwitch(context);
                              },
                              items: [SegmentItem(context.tr('arabic')), SegmentItem(context.tr('english'))],
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<AppThemeMode>(
                        valueListenable: AppThemeController.modeNotifier,
                        builder: (context, mode, _) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _settingLabel(Icons.contrast_rounded, context.tr('appearance')),
                              const SizedBox(height: AppSpacing.sm),
                              AppSegmentedControl(
                                selectedIndex: mode.index,
                                onChanged: (i) => AppThemeController.setMode(AppThemeMode.values[i]),
                                items: [
                                  SegmentItem(context.tr('theme_system'), icon: Icons.brightness_auto_rounded),
                                  SegmentItem(context.tr('theme_light'), icon: Icons.light_mode_rounded),
                                  SegmentItem(context.tr('theme_dark'), icon: Icons.dark_mode_rounded),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppListRow(
                        icon: Icons.notifications_none_rounded,
                        title: context.tr('notifications_title'),
                        subtitle: context.tr('notifications_subtitle'),
                        chevron: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationPreferencesPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ─── Account details ─────────────────────────
                  AppSection(
                    title: context.tr('profile_details'),
                    dividerIndent: 64,
                    children: [
                      if (user.mobileNumber != null)
                        _InfoTile(icon: Icons.phone_outlined, title: context.tr('phone'), value: user.mobileNumber!),
                      _InfoTile(
                        icon: Icons.storefront_outlined,
                        title: context.tr('warehouses'),
                        value: user.warehouseCodes.isNotEmpty ? user.warehouseCodes.join(' · ') : '—',
                      ),
                      _InfoTile(
                        icon: Icons.shield_outlined,
                        title: context.tr('roles'),
                        value: user.roles.isNotEmpty ? user.roles.join(' · ') : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton(
                    label: context.tr('logout'),
                    onPressed: () => _logout(context),
                    icon: Icons.logout_rounded,
                    variant: AppButtonVariant.tonal,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    context.tr('system_title'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingLabel(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
        ],
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppListRow(icon: icon, title: value, subtitle: title, titleMaxLines: 2);
  }
}
