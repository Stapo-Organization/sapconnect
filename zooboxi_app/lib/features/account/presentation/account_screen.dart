import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/app_settings.dart';
import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/config/env.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../location/presentation/location_sheet.dart';
import '../../loyalty/data/loyalty_repository.dart';
import 'widgets/account_header.dart';
import 'widgets/settings_tile.dart';

/// The account tab.
///
/// Language and theme work fully — a customer who wants the app in English at
/// midnight should get both without waiting for a release. Everything below
/// them is a navigable stub until its feature lands.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(appSettingsProvider);
    // Read, never awaited: the account tab renders in full whether or not the
    // loyalty layer answers.
    final loyalty = ref.watch(loyaltySummaryProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: ListView(
        // The floating tab bar's height arrives as bottom padding, so sign-out
        // never ends up under the glass.
        padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          AccountHeader(
            user: session.user,
            onSignIn: () => showAuthSheet(context, reason: l.accountGuestHint),
            tier: loyalty?.tier,
            paws: loyalty?.paws.balance,
            onOpenFamily: () => context.push('/family'),
          ),
          Gap.h24,

          SettingsSection(
            title: l.accountTitle,
            children: [
              SettingsTile(
                icon: Icons.receipt_long_rounded,
                label: l.accountOrders,
                onTap: () => _requireAuth(context, ref, () => context.push('/orders')),
              ),
              SettingsTile(
                icon: Icons.replay_rounded,
                label: l.accountBuyAgain,
                onTap: () => _requireAuth(context, ref, () => context.push('/buy-again')),
              ),
              SettingsTile(
                icon: Icons.favorite_border_rounded,
                label: l.accountWishlist,
                onTap: () => context.push('/wishlist'),
              ),
              SettingsTile(
                icon: Icons.pets_rounded,
                label: l.familyTitle,
                onTap: () => context.push('/family'),
              ),
              SettingsTile(
                icon: Icons.diversity_1_rounded,
                label: l.petsTitle,
                onTap: () => _requireAuth(context, ref, () => context.push('/pets')),
              ),
              SettingsTile(
                icon: Icons.place_outlined,
                label: l.accountAddresses,
                onTap: () => _requireAuth(context, ref, () => context.push('/addresses')),
              ),
            ],
          ),
          Gap.h16,

          SettingsSection(
            title: l.accountPreferences,
            children: [
              SettingsTile(
                icon: Icons.location_on_outlined,
                label: l.locationDeliverTo,
                trailingLabel: ref
                        .watch(currentLocationProvider)
                        .cityFor(settings.languageCode) ??
                    l.locationUnknownCity,
                onTap: () => showLocationSheet(context),
              ),
              SettingsTile(
                icon: Icons.translate_rounded,
                label: l.accountLanguage,
                trailingLabel: settings.languageCode == 'ar'
                    ? l.accountLanguageArabic
                    : l.accountLanguageEnglish,
                onTap: () => _pickLanguage(context, ref, settings),
              ),
              SettingsTile(
                icon: Icons.brightness_6_outlined,
                label: l.accountTheme,
                trailingLabel: switch (settings.themeMode) {
                  ThemeMode.light => l.accountThemeLight,
                  ThemeMode.dark => l.accountThemeDark,
                  ThemeMode.system => l.accountThemeSystem,
                },
                onTap: () => _pickTheme(context, ref, settings),
              ),
            ],
          ),
          Gap.h16,

          SettingsSection(
            title: l.accountSupport,
            children: [
              SettingsTile(
                icon: Icons.support_agent_rounded,
                label: l.accountSupport,
                trailingLabel: l.accountSoon,
                onTap: () => _soon(context),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                label: l.accountAbout,
                trailingLabel: l.accountVersion(Env.appVersion),
                onTap: null,
              ),
            ],
          ),

          if (session.isAuthenticated) ...[
            Gap.h24,
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(l.accountLogout),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.cs.error,
                side: BorderSide(color: context.cs.error.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _requireAuth(
    BuildContext context,
    WidgetRef ref,
    VoidCallback then,
  ) async {
    if (ref.read(sessionProvider).isAuthenticated) {
      then();
      return;
    }
    final signedIn = await showAuthSheet(context, reason: L.of(context).authRequired);
    if (signedIn && context.mounted) then();
  }

  static void _soon(BuildContext context) {
    Haptics.light();
    AppToast.info(context, L.of(context).commonComingSoon);
  }

  static Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l = L.of(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              ('ar', l.accountLanguageArabic),
              ('en', l.accountLanguageEnglish),
            ])
              ListTile(
                title: Text(entry.$2),
                trailing: settings.languageCode == entry.$1
                    ? Icon(Icons.check_rounded, color: context.cs.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.$1),
              ),
            Gap.h8,
          ],
        ),
      ),
    );
    if (chosen == null) return;
    Haptics.selection();
    // Also swaps the type family and re-lays the whole app out RTL/LTR.
    await ref.read(appSettingsProvider.notifier).setLocale(chosen);
  }

  static Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l = L.of(context);
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              (ThemeMode.light, l.accountThemeLight, Icons.light_mode_rounded),
              (ThemeMode.dark, l.accountThemeDark, Icons.dark_mode_rounded),
              (ThemeMode.system, l.accountThemeSystem, Icons.brightness_auto_rounded),
            ])
              ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$2),
                trailing: settings.themeMode == entry.$1
                    ? Icon(Icons.check_rounded, color: context.cs.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.$1),
              ),
            Gap.h8,
          ],
        ),
      ),
    );
    if (chosen == null) return;
    Haptics.selection();
    await ref.read(appSettingsProvider.notifier).setThemeMode(chosen);
  }

  static Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.accountLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.cs.error),
            child: Text(l.accountLogout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionProvider.notifier).logout();
  }
}
