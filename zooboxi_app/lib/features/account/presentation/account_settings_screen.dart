import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/settings/app_settings.dart';
import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/config/app_version.dart';
import '../../../core/config/env.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/support/support_chat.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../location/presentation/location_sheet.dart';
import '../../meta/data/meta_repository.dart';
import '../../notifications/data/push_repository.dart';
import '../../orders/data/orders_repository.dart';
import 'widgets/settings_tile.dart';

/// «الإعدادات» — everything «حسابي» used to list under its shortcuts, one tap
/// behind the gear: preferences, help, and leaving. The account tab itself is
/// about the customer and their pets; this page is about the app.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(appSettingsProvider);
    final active = ref.watch(topActiveOrderProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.accountSettings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (session.isAuthenticated) ...[
            SettingsSection(
              title: l.accountSettingsAccount,
              children: [
                SettingsTile(
                  icon: Icons.place_outlined,
                  label: l.accountAddresses,
                  onTap: () => context.push('/addresses'),
                ),
                SettingsTile(
                  icon: Icons.pets_rounded,
                  label: l.petsTitle,
                  onTap: () => context.push('/pets'),
                ),
              ],
            ),
            Gap.h16,
          ],
          SettingsSection(
            title: l.accountPreferences,
            children: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                label: l.notificationsTitle,
                // What is waiting in the inbox, when something is. A failed
                // read shows nothing at all: an unread count is a promise.
                trailingLabel: switch (ref.watch(inboxProvider).value?.unread ?? 0) {
                  0 => null,
                  final unread => l.inboxUnread(unread),
                },
                onTap: () => context.push('/notifications'),
              ),
              SettingsTile(
                icon: Icons.location_on_outlined,
                label: l.locationDeliverTo,
                trailingLabel:
                    ref.watch(currentLocationProvider).cityFor(settings.languageCode) ?? l.locationUnknownCity,
                onTap: () => showLocationSheet(context),
              ),
              SettingsTile(
                icon: Icons.translate_rounded,
                label: l.accountLanguage,
                trailingLabel: settings.languageCode == 'ar' ? l.accountLanguageArabic : l.accountLanguageEnglish,
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
            title: l.accountSettingsHelp,
            children: [
              // Only while the store has a number: a support row that says
              // «قريباً» in a shop already taking orders promises help and
              // gives none.
              if (ref.watch(supportWhatsappProvider) case final number?)
                SettingsTile(
                  icon: Icons.chat_rounded,
                  label: l.supportWhatsapp,
                  trailingLabel: ref.watch(metaProvider).value?.supportHours ?? l.supportAvailable,
                  onTap: () {
                    Haptics.light();
                    openSupportChat(context, number: number, orderNumber: active?.order.number);
                  },
                ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                label: l.accountAbout,
                trailingLabel: l.accountVersion(
                  Env.appVersion == kAppVersion ? '$kAppVersion ($kAppBuild)' : Env.appVersion,
                ),
                onTap: null,
              ),
            ],
          ),
          if (session.isAuthenticated) ...[
            Gap.h16,
            SettingsSection(
              children: [
                SettingsTile(
                  icon: Icons.logout_rounded,
                  label: l.accountLogout,
                  destructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
                // App Store rule 5.1.1(v): an app that creates accounts must
                // let the person delete one from inside it.
                SettingsTile(
                  icon: Icons.person_off_outlined,
                  label: l.accountDelete,
                  destructive: true,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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

  /// Two honest sentences and a red button. No "are you really sure" cascade:
  /// the person read the words, and the words say exactly what goes and what
  /// stays.
  static Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.accountDeleteConfirmTitle),
        content: Text(l.accountDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.cs.error),
            child: Text(l.accountDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Haptics.light();
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
      if (context.mounted) AppToast.info(context, l.accountDeleted);
    } catch (_) {
      if (context.mounted) AppToast.error(context, l.accountDeleteFailed);
    }
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
