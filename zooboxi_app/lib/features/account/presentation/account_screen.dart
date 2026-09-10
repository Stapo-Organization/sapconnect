import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../orders/data/live_tracking.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/presentation/widgets/order_status_pill.dart';
import 'widgets/account_hero.dart';
import 'widgets/account_quick_actions.dart';
import 'widgets/settings_tile.dart';

/// The account tab.
///
/// It opens with **who you are and what you have** — a canvas carrying the
/// name, the standing, and three counts that are each a door — then the four
/// things people actually come here to do, and only then the settings. The old
/// screen was eleven identical rows in a list; a customer scanning it had to
/// read every one to find «طلباتي», and nothing on it said the shop knew them.
///
/// Everything on the canvas is real: the counts come from the loyalty summary
/// and the orders feed. Nothing is invented to fill a tile — a figure the shop
/// cannot stand behind is worse than an empty space.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(appSettingsProvider);
    // Read, never awaited: the account tab renders in full whether or not the
    // loyalty layer answers.
    final loyalty = ref.watch(loyaltySummaryProvider).value;
    final active = ref.watch(topActiveOrderProvider);

    // The canvas runs behind the status bar and a pinned bar keeps a teal
    // ground up there after it scrolls away, so the clock is light for the
    // whole screen instead of flickering at one scroll offset.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: heroTop(context),
              surfaceTintColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: Text(
                l.accountTitle,
                style: context.tt.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AccountHero(
                user: session.user,
                onSignIn: () => showAuthSheet(context, reason: l.accountGuestHint),
                tier: loyalty?.tier,
                paws: loyalty?.paws.balance,
                orders: loyalty?.counters.ordersTotal,
                pets: loyalty?.pets.length,
                onOpenFamily: () => context.push('/family'),
                onOpenOrders: () =>
                    _requireAuth(context, ref, () => context.push('/orders')),
                onOpenPets: () => _requireAuth(context, ref, () => context.push('/pets')),
              ),
            ),
            SliverPadding(
              // The floating tab bar's height arrives as bottom padding, so sign
              // out never ends up under the glass.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  // The one thing that outranks everything else on this screen:
                  // a parcel that is moving right now.
                  if (active != null) ...[
                    _ActiveOrderCard(
                      active: active,
                      onTap: () => context.push('/orders/${active.order.id}'),
                    ),
                    Gap.h16,
                  ],

                  AccountQuickActions(
                    actions: [
                      QuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: l.ordersTitle,
                        tint: cs.primary,
                        onTap: () =>
                            _requireAuth(context, ref, () => context.push('/orders')),
                      ),
                      QuickAction(
                        icon: Icons.replay_rounded,
                        label: l.accountBuyAgainShort,
                        tint: context.zb.success,
                        onTap: () =>
                            _requireAuth(context, ref, () => context.push('/buy-again')),
                      ),
                      QuickAction(
                        icon: Icons.favorite_rounded,
                        label: l.wishlistTitle,
                        tint: context.zb.sale,
                        onTap: () => context.push('/wishlist'),
                      ),
                      QuickAction(
                        icon: Icons.place_rounded,
                        label: l.accountAddresses,
                        tint: context.zb.warning,
                        onTap: () =>
                            _requireAuth(context, ref, () => context.push('/addresses')),
                      ),
                    ],
                  ),
                  Gap.h20,

                  SettingsSection(
                    title: l.familyTitle,
                    children: [
                      SettingsTile(
                        icon: Icons.workspace_premium_rounded,
                        label: l.familyTitle,
                        // No standing here: the canvas above already says it,
                        // and a fact printed twice on one screen reads as two
                        // facts that happen to agree.
                        onTap: () => context.push('/family'),
                      ),
                      SettingsTile(
                        icon: Icons.pets_rounded,
                        label: l.petsTitle,
                        onTap: () =>
                            _requireAuth(context, ref, () => context.push('/pets')),
                      ),
                    ],
                  ),
                  Gap.h16,

                  SettingsSection(
                    title: l.accountPreferences,
                    children: [
                      SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        label: l.notificationsTitle,
                        onTap: () => context.push('/notifications'),
                      ),
                      SettingsTile(
                        icon: Icons.location_on_outlined,
                        label: l.locationDeliverTo,
                        trailingLabel:
                            ref
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
                      if (session.isAuthenticated) ...[
                        SettingsTile(
                          icon: Icons.logout_rounded,
                          label: l.accountLogout,
                          destructive: true,
                          onTap: () => _confirmLogout(context, ref),
                        ),
                        // App Store rule 5.1.1(v): an app that creates accounts
                        // must let the person delete one from inside it.
                        SettingsTile(
                          icon: Icons.person_off_outlined,
                          label: l.accountDelete,
                          destructive: true,
                          onTap: () => _confirmDelete(context, ref),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// The parcel that is moving right now.
///
/// It is above the shortcuts because it expires: everything else on this
/// screen will still be true tomorrow, and this will not.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.active, required this.onTap});

  final ActiveOrder active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final order = active.order;

    return Material(
      color: cs.primaryContainer.withValues(alpha: context.isDark ? 0.45 : 0.5),
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  active.hasCourier
                      ? Icons.delivery_dining_rounded
                      : Icons.inventory_2_rounded,
                  size: 22,
                  color: cs.primary,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.accountActiveOrder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    Gap.h4,
                    Row(
                      children: [
                        OrderStatusPill(order: order, compact: true),
                        Gap.w6,
                        Flexible(
                          child: Text(
                            '#${order.number}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: context.tt.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Gap.w8,
              Icon(
                context.isRtl
                    ? Icons.keyboard_arrow_left_rounded
                    : Icons.keyboard_arrow_right_rounded,
                color: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
