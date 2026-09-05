import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../pets/data/pet_models.dart';
import '../../pets/presentation/widgets/species_avatar.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/grant_card.dart';
import 'widgets/mission_card.dart';
import 'widgets/reward_card.dart';
import 'widgets/scratch_card_view.dart';
import 'widgets/tier_card.dart';

/// «عائلة زوبوكسي» — the whole program on one screen.
///
/// Order is deliberate: standing first (it is the thing that took months to
/// earn), then the wallet, then anything waiting on the customer — an unopened
/// scratch card, a mission mid-progress — and only then the catalogue. Nothing
/// here is a discount, so nothing here shouts.
class FamilyHubScreen extends ConsumerWidget {
  const FamilyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final signedIn = ref.watch(isAuthenticatedProvider);
    final summary = ref.watch(loyaltySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.familyTitle)),
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
    final locale = Localizations.localeOf(context).languageCode;
    final rewards = ref.watch(loyaltyRewardsProvider).value ?? RewardsCatalog.empty;
    final grants = rewards.activeGrants;
    final catalog = rewards.catalog.where((reward) => reward.isPurchasable).toList();
    final missions = summary.missions.items;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        TierCard(
          tier: summary.tier,
          paws: summary.paws,
          onPawsTap: () => context.push('/family/ledger'),
        ),
        Gap.h12,

        _WalletRow(
          onHowTo: () => _showHowToEarn(context),
          onLedger: () => context.push('/family/ledger'),
        ),

        if (summary.pets.isNotEmpty) ...[
          Gap.h16,
          _PetsRow(pets: summary.pets, onOpen: () => context.push('/pets')),
        ],

        if (summary.hasSealedScratch) ...[
          Gap.h24,
          SectionHeader(title: l.familySealedTitle, padding: EdgeInsets.zero),
          Gap.h12,
          for (final card in summary.rewards.sealedScratch) ...[
            SealedScratchTile(
              orderNumber: card.orderNumber,
              onTap: () => context.push('/family/scratch/${card.id}'),
            ),
            Gap.h8,
          ],
        ],

        if (summary.playsGames && missions.isNotEmpty) ...[
          Gap.h24,
          SectionHeader(
            title: l.missionsTitle,
            subtitle: l.missionsSubtitle,
            padding: EdgeInsets.zero,
          ),
          Gap.h12,
          for (final mission in missions) ...[
            MissionCard(mission: mission),
            Gap.h12,
          ],
        ],

        if (grants.isNotEmpty) ...[
          Gap.h24,
          SectionHeader(
            title: l.familyMyRewards,
            padding: EdgeInsets.zero,
            onSeeAll: () => context.push('/family/rewards'),
          ),
          Gap.h12,
          for (final grant in grants.take(3)) ...[
            GrantCard(grant: grant),
            Gap.h12,
          ],
        ],

        if (catalog.isNotEmpty) ...[
          Gap.h24,
          SectionHeader(
            title: l.familyRedeemTitle,
            padding: EdgeInsets.zero,
            onSeeAll: () => context.push('/family/rewards'),
          ),
          Gap.h12,
          for (final reward in catalog.take(3)) ...[
            RewardCard(
              reward: reward,
              balance: summary.paws.balance,
              onRedeem: () => context.push('/family/rewards'),
            ),
            Gap.h12,
          ],
        ],

        Gap.h16,
        Center(
          child: Text(
            [
              if (summary.member.joinedAt != null)
                l.familyMemberSince(Fmt.dateShort(summary.member.joinedAt!, locale)),
              if ((summary.member.referralCode ?? '').isNotEmpty)
                l.familyReferralCode(summary.member.referralCode!),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
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
              for (final line in [
                l.pawsHowOrder,
                l.pawsHowProfile,
                l.pawsHowPet,
                l.pawsHowPlay,
                l.pawsHowDelivered,
                l.pawsHowExpiry,
              ]) ...[
                _HowRow(text: line),
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
  const _HowRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.check_rounded, size: 16, color: context.cs.primary),
          ),
          Gap.w8,
          Expanded(child: Text(text, style: context.tt.bodyMedium)),
        ],
      );
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.onHowTo, required this.onLedger});

  final VoidCallback onHowTo;
  final VoidCallback onLedger;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onHowTo,
            icon: const Icon(Icons.help_outline_rounded, size: 17),
            label: Text(l.pawsHowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ),
        Gap.w8,
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onLedger,
            icon: const Icon(Icons.history_rounded, size: 17),
            label: Text(l.familyLedgerLink, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ),
      ],
    );
  }
}

/// The family itself, one row of portraits. The hub is named after them.
class _PetsRow extends StatelessWidget {
  const _PetsRow({required this.pets, required this.onOpen});

  final List<Pet> pets;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return PressScale(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            for (final pet in pets.take(3)) ...[
              SpeciesAvatar(species: pet.species, size: 40),
              Gap.w8,
            ],
            Expanded(
              child: Text(
                // The list separator is punctuation, and punctuation is part
                // of the language: «مشمش، ريم» in Arabic, "Mishmish, Reem" in
                // English.
                pets
                    .map((pet) => pet.name)
                    .join(Localizations.localeOf(context).languageCode == 'ar'
                        ? '، '
                        : ', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              context.isRtl
                  ? Icons.keyboard_arrow_left_rounded
                  : Icons.keyboard_arrow_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubSkeleton extends StatelessWidget {
  const _HubSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 210, radius: ZbTokens.rXl),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 44, radius: ZbTokens.rMd),
            Gap.h24,
            SkeletonBox(width: double.infinity, height: 120, radius: ZbTokens.rLg),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 120, radius: ZbTokens.rLg),
          ],
        ),
      );
}
