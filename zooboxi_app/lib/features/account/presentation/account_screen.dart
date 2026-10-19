import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/config/app_version.dart';
import '../../../core/config/env.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/support/support_chat.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../catalog/data/product_models.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../notifications/data/push_repository.dart';
import '../../orders/data/orders_repository.dart';
import '../../wishlist/data/wishlist_controller.dart';
import '../data/account_repository.dart';
import '../data/addresses_controller.dart';
import 'widgets/account_dashboard.dart';
import 'widgets/settings_tile.dart';

/// The account tab — «حسابي».
///
/// It is about the customer, not the app: the membership card the characters
/// sit on, the parcel on its way, a card per pet with its food, and tiles that
/// carry their own numbers. Preferences, help and signing out are one tap
/// away behind the gear (see AccountSettingsScreen).
///
/// Everything drawn here is real — the loyalty summary, the orders feed, the
/// household, the wishlist and the address book. A member who has not ordered
/// yet never sees a row of zeros: the card says what the first order starts,
/// and the pets' place asks who lives with them.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final session = ref.watch(sessionProvider);
    final authed = session.isAuthenticated;
    // Read, never awaited: the tab renders in full whether or not the loyalty
    // layer answers.
    final loyalty = authed ? ref.watch(loyaltySummaryProvider).value : null;
    final active = ref.watch(topActiveOrderProvider);
    final orders = loyalty?.counters.ordersTotal ?? 0;
    final pets = loyalty?.pets ?? const [];

    final top = <Widget>[
      _TopBar(
        unread: authed ? (ref.watch(inboxProvider).value?.unread ?? 0) : 0,
        onInbox: () => _requireAuth(context, ref, () => context.push('/inbox')),
        onSettings: () => context.push('/account/settings'),
      ),
      if (authed)
        MemberCard(
          name: session.user?.name.trim().isNotEmpty == true ? session.user!.name.trim() : l.accountMemberFallback,
          tier: loyalty?.tier,
          paws: loyalty?.paws.balance ?? 0,
          pending: loyalty?.paws.pending ?? 0,
          onTap: () => context.push('/family'),
          onRewards: () => context.push('/family/rewards'),
        )
      else
        GuestInviteCard(onSignIn: () => showAuthSheet(context, reason: l.accountGuestHint)),
      // The one thing that outranks everything else here: a parcel moving now.
      if (active != null) ...[
        Gap.h16,
        LiveOrderTile(active: active, onTap: () => context.push('/orders/${active.order.id}')),
      ],
    ];

    final List<Widget> rest;
    if (!authed) {
      rest = [Gap.h16, const GuestPerks()];
    } else {
      final List<ProductCard> buyAgain = orders > 0 ? (ref.watch(buyAgainProvider).value ?? const []) : const [];
      final wishlist = ref.watch(wishlistControllerProvider);
      final wishlistImages = wishlist.isEmpty
          ? const <String>[]
          : <String>[
              for (final ProductCard p in ref.watch(wishlistProductsProvider).value ?? const <ProductCard>[])
                if (p.image != null) p.image!,
            ];
      final addresses = ref.watch(addressesControllerProvider).value ?? const [];
      final referral = loyalty?.referral;
      final dark = context.isDark;

      rest = [
        _SectionTitle(l.accountShortcuts),
        const SizedBox(height: 10),
        if (orders == 0)
          FirstOrderTile(onTap: () => context.go('/home'))
        else if (buyAgain.isNotEmpty)
          UsualTile(products: buyAgain, onOpen: () => context.push('/buy-again')),
        const SizedBox(height: 10),
        TilePair(
          start: orders > 0
              ? AccountTile(
                  icon: Icons.receipt_long_rounded,
                  tint: dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint,
                  color: dark ? ZbTokens.tealOnDark : ZbTokens.tealDark,
                  title: l.ordersTitle,
                  count: orders,
                  images: <String>[for (final p in buyAgain) if (p.image != null) p.image!],
                  onTap: () => context.push('/orders'),
                )
              : AccountTile(
                  icon: Icons.place_rounded,
                  tint: dark ? ZbTokens.amberContainerDark : ZbTokens.amberTintSoft,
                  color: ZbTokens.cardboard,
                  title: l.accountAddresses,
                  count: addresses.length,
                  hint: addresses.isEmpty ? l.accountAddressesHint : _labels(addresses.map((a) => a.label ?? ''), context),
                  onTap: () => context.push('/addresses'),
                ),
          end: AccountTile(
            icon: Icons.favorite_rounded,
            tint: dark ? ZbTokens.coralContainerDark : ZbTokens.coralTintSoft,
            color: ZbTokens.coral,
            title: l.wishlistTitle,
            count: wishlist.length,
            hint: l.accountWishlistHint,
            images: wishlistImages,
            onTap: () => context.push('/wishlist'),
          ),
        ),
        if (orders > 0 || referral != null) ...[
          const SizedBox(height: 10),
          TilePair(
            start: orders > 0
                ? AccountTile(
                    icon: Icons.place_rounded,
                    tint: dark ? ZbTokens.amberContainerDark : ZbTokens.amberTintSoft,
                    color: ZbTokens.cardboard,
                    title: l.accountAddresses,
                    count: addresses.length,
                    hint: addresses.isEmpty ? l.accountAddressesHint : _labels(addresses.map((a) => a.label ?? ''), context),
                    onTap: () => context.push('/addresses'),
                  )
                : _friendsTile(context, referral!.rewarded),
            end: orders > 0 && referral != null ? _friendsTile(context, referral.rewarded) : null,
          ),
        ],
        if (referral != null) ...[
          const SizedBox(height: 10),
          InviteTile(rewardPaws: referral.rewardPaws, onTap: () => context.push('/family/referral')),
        ],
      ];
    }

    final number = ref.watch(supportWhatsappProvider);
    final footer = <Widget>[
      if (number != null) ...[
        Gap.h16,
        SettingsSection(
          children: [
            SettingsTile(
              icon: Icons.chat_rounded,
              label: l.accountHelp,
              onTap: () {
                Haptics.light();
                openSupportChat(context, number: number, orderNumber: active?.order.number);
              },
            ),
          ],
        ),
      ],
      Gap.h12,
      Center(
        child: Text(
          l.accountVersionFooter(Env.appVersion == kAppVersion ? '$kAppVersion ($kAppBuild)' : Env.appVersion),
          style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant.withValues(alpha: 0.7)),
        ),
      ),
    ];

    const side = EdgeInsets.symmetric(horizontal: 16);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: side.copyWith(top: 12),
                sliver: SliverList.list(children: top),
              ),
            ),
            if (authed) ...[
              SliverPadding(
                padding: side.copyWith(top: 22, bottom: 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(
                    l.accountPetsTitle,
                    action: pets.isEmpty ? null : l.petsTitle,
                    onAction: () => context.push('/pets'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: pets.isEmpty
                    ? Padding(
                        padding: side,
                        child: HouseholdInviteCard(onTap: () => context.push('/pets/new')),
                      )
                    : PetCardsRow(pets: pets, summary: loyalty),
              ),
            ],
            SliverPadding(
              // The floating tab bar's height arrives as bottom padding, so the
              // last row never ends up under the glass.
              padding: side.copyWith(top: 20, bottom: 28 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverList.list(children: [...rest, ...footer]),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _friendsTile(BuildContext context, int joined) {
    final l = L.of(context);
    final dark = context.isDark;
    return AccountTile(
      icon: Icons.card_giftcard_rounded,
      tint: dark ? ZbTokens.tealContainerDark : ZbTokens.tealTintSoft,
      color: dark ? ZbTokens.tealOnDark : ZbTokens.tealDeep,
      title: l.accountFriends,
      count: joined,
      hint: joined > 0 ? l.accountFriendsJoined(joined) : l.accountFriendsNone,
      onTap: () => context.push('/family/referral'),
    );
  }

  static String _labels(Iterable<String> labels, BuildContext context) =>
      labels.where((s) => s.trim().isNotEmpty).take(2).join(' · ');

  static Future<void> _requireAuth(BuildContext context, WidgetRef ref, VoidCallback then) async {
    if (ref.read(sessionProvider).isAuthenticated) {
      then();
      return;
    }
    final signedIn = await showAuthSheet(context, reason: L.of(context).authRequired);
    if (signedIn && context.mounted) then();
  }
}

/// «مساء الخير / حسابي», with the inbox bell and the settings gear.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.unread, required this.onInbox, required this.onSettings});

  final int unread;
  final VoidCallback onInbox;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final hour = DateTime.now().hour;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hour < 12 ? l.accountGreetMorning : l.accountGreetEvening,
                style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              Text(l.accountTitle, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        _RoundButton(
          icon: Icons.notifications_none_rounded,
          label: l.notificationsTitle,
          dot: unread > 0,
          onTap: onInbox,
        ),
        Gap.w8,
        _RoundButton(icon: Icons.settings_rounded, label: l.accountSettings, onTap: onSettings),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.dot = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: cs.surface,
        shape: CircleBorder(side: BorderSide(color: context.isDark ? ZbTokens.lineDark : ZbTokens.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: cs.onSurface),
                if (dot)
                  PositionedDirectional(
                    top: 10,
                    end: 11,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: ZbTokens.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
            child: Text(action!),
          ),
      ],
    );
  }
}

