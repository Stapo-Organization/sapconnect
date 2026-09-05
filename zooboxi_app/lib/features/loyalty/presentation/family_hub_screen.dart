import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/motion/motion.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/error_text.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../cart/data/cart_controller.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../pets/data/pet_models.dart';
import '../../pets/presentation/widgets/species_avatar.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'referral_screen.dart' show shareReferral;
import 'widgets/grant_card.dart';
import 'widgets/loyalty_art.dart';
import 'widgets/mission_card.dart';
import 'widgets/moment_cards.dart';
import 'widgets/paws_pill.dart';
import 'widgets/reward_card.dart';
import 'widgets/scratch_card_view.dart';
import 'widgets/subscription_card.dart';
import 'widgets/supply_card.dart';
import 'widgets/tier_card.dart';

/// «عائلة زوبوكسي» — the whole program on one screen.
///
/// Order is deliberate: the membership card first (standing and wallet are
/// the things that took months to earn), then anything waiting on the
/// customer — an order on its way, an unopened scratch card, a mission
/// mid-progress — then the family itself, then the shelf. Nothing here is a
/// discount, so nothing here shouts; but everything here is drawn.
class FamilyHubScreen extends ConsumerWidget {
  const FamilyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final signedIn = ref.watch(isAuthenticatedProvider);
    final summary = ref.watch(loyaltySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.familyTitle),
        actions: [
          if (signedIn && summary.value != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: PawsPill(
                  paws: summary.value!.paws.balance,
                  compact: true,
                  onTap: () => context.push('/family/ledger'),
                ),
              ),
            ),
        ],
      ),
      body: !signedIn
          ? const _GuestInvitation()
          : RefreshIndicator.adaptive(
              onRefresh: () async {
                invalidateLoyalty(ref);
                await ref.read(loyaltySummaryProvider.future);
              },
              child: AsyncView<LoyaltySummary?>(
                value: summary,
                onRetry: () => ref.invalidate(loyaltySummaryProvider),
                skeleton: const _HubSkeleton(),
                // A signed-in customer always has a summary; the null branch
                // only happens in the beat after a sign-out, and an invitation
                // is a kinder thing to land on than an error.
                builder: (data) =>
                    data == null ? const _GuestInvitation() : _Hub(summary: data),
              ),
            ),
    );
  }
}

/// What a guest sees. Never a 401 screen: they are not broken, they simply
/// don't have an account yet, and the honest response to that is an invitation.
class _GuestInvitation extends ConsumerWidget {
  const _GuestInvitation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    return EmptyState(
      icon: Icons.pets_rounded,
      title: l.familyGuestTitle,
      message: l.familyGuestBody,
      actionLabel: l.familyGuestCta,
      mascot: true,
      onAction: () async {
        final signedIn = await showAuthSheet(context, reason: l.familyGuestBody);
        if (signedIn) ref.invalidate(loyaltySummaryProvider);
      },
    );
  }
}

class _Hub extends ConsumerWidget {
  const _Hub({required this.summary});

  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final rewards = ref.watch(loyaltyRewardsProvider).value ?? RewardsCatalog.empty;
    final grants = rewards.activeGrants;
    // A gift with no product behind it is the owner's unfinished work; the
    // customer's shelf only shows what can actually be taken home.
    final catalog = rewards.catalog
        .where((reward) => reward.isPurchasable && !(reward.isGift && reward.product == null))
        .toList();
    final missions = summary.missions.items;
    final (_, tierEnd) = TierChip.colorsOf(context, summary.tier.c1, summary.tier.c2);
    final still = context.reduceMotion;

    var i = 0;
    Widget enter(Widget child) {
      if (still) return child;
      final delay = Duration(milliseconds: 60 * i++);
      return child
          .animate(delay: delay)
          .fadeIn(duration: Motion.enter, curve: Motion.decelerate)
          .slideY(begin: 0.06, end: 0, duration: Motion.enter, curve: Motion.decelerate);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        enter(
          TierCard(
            tier: summary.tier,
            paws: summary.paws,
            pet: summary.firstPet,
            pendingOrders: summary.pendingOrders,
            onPawsTap: () => context.push('/family/ledger'),
          ),
        ),
        Gap.h12,

        enter(
          _QuickActions(
            onHowTo: () => _showHowToEarn(context),
            onLedger: () => context.push('/family/ledger'),
            onPets: () => context.push('/pets'),
          ),
        ),

        // The moment: a pet's birthday this week, with its gift.
        if (_birthday(summary) != null) ...[
          Gap.h12,
          enter(
            BirthdayCard(
              moment: _birthday(summary)!,
              onClaim: () => _claimBirthday(context, ref, _birthday(summary)!),
            ),
          ),
        ],

        // An order on its way: the one card that answers "where is my reward?".
        for (final order in summary.pendingOrders) ...[
          Gap.h12,
          enter(
            PendingOrderCard(
              order: order,
              awaitingMission: summary.playsGames &&
                  order.isApp &&
                  missions.any((m) => !m.isDone && (m.kind == 'welcome' || m.kind == 'frequency')),
            ),
          ),
        ],

        if (summary.hasSealedScratch) ...[
          Gap.h20,
          enter(_Header(title: l.familySealedTitle)),
          Gap.h12,
          for (final card in summary.rewards.sealedScratch) ...[
            enter(
              SealedScratchTile(
                orderNumber: card.orderNumber,
                onTap: () => context.push('/family/scratch/${card.id}'),
              ),
            ),
            Gap.h8,
          ],
        ],

        // «مخزون البيت» — the gauge: the thesis of the whole program.
        if (summary.supply.items.isNotEmpty) ...[
          Gap.h20,
          enter(
            _Header(
              title: l.supplyTitle,
              subtitle: l.supplyHubSubtitle,
              onSeeAll: () => context.push('/family/supply'),
            ),
          ),
          Gap.h12,
          for (final item in summary.supply.items.take(3)) ...[
            enter(
              SupplyGaugeCard(
                item: item,
                compact: true,
                onTimePct: summary.supply.onTimePct,
                onOrder: () => _orderSupply(context, ref, item),
              ),
            ),
            Gap.h12,
          ],
        ],

        // «اشتراكاتي» — the next delivery, and the door to the rest.
        if (summary.subscriptions.next != null) ...[
          Gap.h8,
          enter(
            _Header(
              title: l.subsTitle,
              subtitle: l.subsHubSubtitle(summary.subscriptions.active),
              onSeeAll: () => context.push('/family/subscriptions'),
            ),
          ),
          Gap.h12,
          enter(
            SubscriptionCard(
              sub: summary.subscriptions.next!,
              compact: true,
              onOrderNow: () => _orderSubscription(context, ref, summary.subscriptions.next!),
              onEdit: () => context.push('/family/subscriptions'),
            ),
          ),
        ],

        Gap.h20,
        enter(_FamilyRail(pets: summary.pets, canAdd: true)),

        if (summary.playsGames && missions.isNotEmpty) ...[
          Gap.h20,
          enter(
            _Header(
              title: l.missionsTitle,
              subtitle: l.missionsSubtitle,
              trailing: _DoneCounter(
                done: missions.where((m) => m.isDone).length,
                total: missions.length,
                accent: tierEnd,
              ),
            ),
          ),
          Gap.h12,
          for (final mission in missions) ...[
            enter(
              MissionCard(
                mission: mission,
                awaitingDelivery: summary.hasPendingAppOrder &&
                    (mission.kind == 'welcome' || mission.kind == 'frequency'),
              ),
            ),
            Gap.h12,
          ],
        ],

        if (grants.isNotEmpty) ...[
          Gap.h12,
          enter(_Header(title: l.familyMyRewards, onSeeAll: () => context.push('/family/rewards'))),
          Gap.h12,
          for (final grant in grants.take(3)) ...[
            enter(GrantCard(grant: grant)),
            Gap.h12,
          ],
        ],

        if (catalog.isNotEmpty) ...[
          Gap.h12,
          enter(_Header(title: l.familyRedeemTitle, onSeeAll: () => context.push('/family/rewards'))),
          Gap.h12,
          enter(
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: catalog.length,
                separatorBuilder: (_, _) => Gap.w12,
                itemBuilder: (context, index) => RewardShelfTile(
                  reward: catalog[index],
                  balance: summary.paws.balance,
                  onTap: () => context.push('/family/rewards'),
                ),
              ),
            ),
          ),
        ],

        // «ادعُ صديقاً».
        if (summary.referral != null) ...[
          Gap.h20,
          enter(
            ReferralCard(
              referral: summary.referral!,
              onOpen: () => context.push('/family/referral'),
              onShare: () => shareReferral(ref, text: '', url: summary.referral!.url),
            ),
          ),
        ],

        // Brand stamp cards — only once the owner has switched a program on.
        if (summary.stamps.isNotEmpty) ...[
          Gap.h20,
          enter(_Header(title: l.stampsTitle)),
          Gap.h12,
          for (final card in summary.stamps) ...[
            enter(StampCardView(card: card)),
            Gap.h12,
          ],
        ],

        Gap.h20,
        enter(_TierPerksSection(perks: summary.tier.perks, accent: tierEnd)),

        Gap.h20,
        enter(_MembershipStrip(summary: summary)),
        Gap.h8,
        Center(
          child: Text(
            l.familyTagline,
            textAlign: TextAlign.center,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  static BirthdayMoment? _birthday(LoyaltySummary summary) {
    final moment = summary.birthday;
    if (moment == null || !moment.eligible) return null;
    if (moment.days >= 0) return moment;
    return moment.grant != null && moment.grant!.isClaimable ? moment : null;
  }

  static Future<void> _orderSupply(BuildContext context, WidgetRef ref, SupplyItem item) async {
    ref.track(ZbEvent(type: ZbEvents.supplyAction, zone: 'family', payload: {'product_id': item.product.id, 'action': 'order'}));
    if (item.product.isVariable && item.variationId <= 0) {
      Haptics.light();
      await context.push<void>('/product/${item.product.id}', extra: item.product);
      return;
    }
    final added = await addToCart(
      context,
      ref,
      product: item.product,
      variationId: item.variationId > 0 ? item.variationId : null,
      quantity: item.qtyLast,
      zone: 'family',
    );
    if (added && context.mounted) unawaited(context.push('/cart'));
  }

  static Future<void> _orderSubscription(BuildContext context, WidgetRef ref, Subscription sub) async {
    try {
      final result = await ref.read(loyaltyRepositoryProvider).orderNow(sub.id);
      ref.read(cartControllerProvider.notifier).applyServerCart(result.cart);
      ref.track(ZbEvent(type: ZbEvents.subscription, zone: 'family', payload: {'subscription_id': sub.id, 'action': 'order'}));
      if (!context.mounted) return;
      await Haptics.success();
      if (!context.mounted) return;
      AppToast.success(context, L.of(context).subsBasketReady);
      unawaited(context.push('/cart'));
    } catch (e) {
      if (context.mounted) AppToast.error(context, errorMessage(context, e));
    }
  }

  static Future<void> _claimBirthday(BuildContext context, WidgetRef ref, BirthdayMoment moment) async {
    final grant = moment.grant;
    if (grant == null) return;
    try {
      await ref.read(cartControllerProvider.notifier).claimGrant(grant.id);
      if (!context.mounted) return;
      await Haptics.success();
      if (!context.mounted) return;
      AppToast.success(context, L.of(context).momentGiftAdded);
      invalidateLoyalty(ref);
      unawaited(context.push('/cart'));
    } catch (e) {
      if (context.mounted) AppToast.error(context, errorMessage(context, e));
    }
  }

  static void _showHowToEarn(BuildContext context) {
    final l = L.of(context);
    unawaited(
      showZbSheet<void>(
        context,
        builder: (_) => BottomSheetScaffold(
          title: l.pawsHowTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (mark, line) in [
                (FamilyMark.family, l.pawsHowOrder),
                (FamilyMark.check, l.pawsHowProfile),
                (FamilyMark.family, l.pawsHowPet),
                (FamilyMark.bulb, l.pawsHowPlay),
                (FamilyMark.clock, l.pawsHowDelivered),
                (FamilyMark.lock, l.pawsHowExpiry),
              ]) ...[
                _HowRow(mark: mark, text: line),
                Gap.h12,
              ],
              Gap.h8,
            ],
          ),
        ),
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.mark, required this.text});

  final FamilyMark mark;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FamilyMarkIcon(mark, size: 22, color: mark == FamilyMark.lock ? null : context.cs.primary),
          Gap.w12,
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: context.tt.bodyMedium))),
        ],
      );
}

/// A section title with an optional count on the end.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.onSeeAll, this.trailing});

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ?subtitle == null
                  ? null
                  : Text(subtitle!, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        ?trailing,
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.actionSeeAll),
                Icon(context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

class _DoneCounter extends StatelessWidget {
  const _DoneCounter({required this.done, required this.total, required this.accent});

  final int done;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          value: total == 0 ? 0 : done / total,
          color: accent,
          size: 26,
          stroke: 3.5,
        ),
        Gap.w8,
        Text(
          l.missionsDoneOf(done, total),
          style: context.tt.labelMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Three painted tiles: how to earn, the ledger, the pets. Tiles, not
/// buttons, so the labels never truncate and each has a face.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onHowTo, required this.onLedger, required this.onPets});

  final VoidCallback onHowTo;
  final VoidCallback onLedger;
  final VoidCallback onPets;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(child: _ActionTile(mark: FamilyMark.bulb, label: l.familyActionHow, onTap: onHowTo)),
        Gap.w8,
        Expanded(child: _ActionTile(mark: FamilyMark.book, label: l.familyActionLedger, onTap: onLedger)),
        Gap.w8,
        Expanded(child: _ActionTile(mark: FamilyMark.family, label: l.familyActionPets, onTap: onPets)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.mark, required this.label, required this.onTap});

  final FamilyMark mark;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FamilyMarkIcon(mark, size: 30, color: mark == FamilyMark.family ? ZbTokens.cardboard : null),
            Gap.h8,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// The family itself: portraits with names, and the bubble that adds one.
/// The hub is named after them, so they get faces, not a row of text.
class _FamilyRail extends StatelessWidget {
  const _FamilyRail({required this.pets, required this.canAdd});

  final List<Pet> pets;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title: l.petsTitle, onSeeAll: pets.isEmpty ? null : () => context.push('/pets')),
        Gap.h12,
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              for (final pet in pets) ...[
                _PetBubble(pet: pet, onTap: () => context.push('/pets/${pet.id}', extra: pet)),
                Gap.w12,
              ],
              if (canAdd)
                PressScale(
                  onTap: () => context.push('/pets/new'),
                  borderRadius: BorderRadius.circular(40),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: context.isDark ? 0.16 : 0.10),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.6),
                          ),
                          alignment: Alignment.center,
                          child: FamilyMarkIcon(FamilyMark.plus, size: 28, color: cs.primary),
                        ),
                        Gap.h8,
                        Text(
                          pets.isEmpty ? l.familyAddPet : l.petsAdd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PetBubble extends StatelessWidget {
  const _PetBubble({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SpeciesAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 68),
                  if (pet.isBirthdaySoon)
                    const PositionedDirectional(
                      end: -2,
                      top: -2,
                      child: RewardSticker(kind: 'gift_product', size: 22),
                    ),
                ],
              ),
              Gap.h8,
              Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _TierPerksSection extends StatelessWidget {
  const _TierPerksSection({required this.perks, required this.accent});

  final List<TierPerk> perks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (perks.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title: l.familyPerksTitle),
        Gap.h12,
        TierPerks(perks: perks, accent: accent),
      ],
    );
  }
}

/// Member since, and the invite code — as a small ticket with a copy action.
class _MembershipStrip extends StatelessWidget {
  const _MembershipStrip({required this.summary});

  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final code = summary.member.referralCode ?? '';
    final since = summary.member.joinedAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? cs.surfaceContainerLow : ZbTokens.cream,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const PawCoin(size: 26),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (since != null)
                  Text(
                    l.familyMemberSince(Fmt.dateShort(since, locale)),
                    style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                if (code.isNotEmpty)
                  Text(
                    '${l.familyReferralTitle} · $code',
                    style: context.tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          if (code.isNotEmpty)
            IconButton(
              tooltip: l.familyReferralTitle,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                Haptics.light();
                if (context.mounted) AppToast.success(context, l.familyReferralCopied);
              },
              icon: Icon(Icons.copy_rounded, size: 18, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _HubSkeleton extends StatelessWidget {
  const _HubSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 250, radius: ZbTokens.rXl),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 78, radius: ZbTokens.rLg),
            Gap.h24,
            SkeletonBox(width: double.infinity, height: 110, radius: ZbTokens.rXl),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 110, radius: ZbTokens.rXl),
          ],
        ),
      );
}
