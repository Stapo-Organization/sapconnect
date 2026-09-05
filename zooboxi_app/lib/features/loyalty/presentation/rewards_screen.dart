import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../cart/data/cart_controller.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/grant_card.dart';
import 'widgets/paws_pill.dart';
import 'widgets/reward_card.dart';

/// The rewards screen: what this customer holds, then what their paws can
/// still buy.
///
/// Owned first on purpose — an unused reward is a promise already made, and
/// burying it under a catalogue is how loyalty programs quietly become
/// unclaimed liabilities.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  int? _busyGrant;
  bool _redeeming = false;

  Future<void> _redeem(Reward reward) async {
    if (_redeeming) return;
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cost = Fmt.number(reward.pawsCost, locale: locale, decimals: 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.rewardRedeemTitle),
        content: Text(l.rewardRedeemBody(cost, reward.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.rewardRedeem),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _redeeming = true);
    Haptics.light();
    try {
      await ref.read(loyaltyRepositoryProvider).redeem(reward.id);
      ref.read(eventsBufferProvider).track(
            ZbEvent(
              type: ZbEvents.loyaltyRedeem,
              zone: 'family',
              payload: {'reward_id': reward.id},
            ),
          );
      invalidateLoyalty(ref);
      if (!mounted) return;
      AppToast.success(context, l.rewardRedeemDone);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        switch (e.code) {
          LoyaltyErrors.insufficientPaws => l.rewardInsufficientPaws,
          LoyaltyErrors.tierRequired => l.rewardTierRequired,
          _ => e.messageFor(locale) ?? l.rewardRedeemFailed,
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _claim(Grant grant) async {
    setState(() => _busyGrant = grant.id);
    final l = L.of(context);
    try {
      await ref.read(cartControllerProvider.notifier).claimGrant(grant.id);
      ref.read(eventsBufferProvider).track(
            ZbEvent(
              type: ZbEvents.loyaltyClaim,
              zone: 'family',
              payload: {'grant_id': grant.id},
            ),
          );
      invalidateLoyalty(ref);
      if (!mounted) return;
      AppToast.success(context, l.rewardInCart);
    } on ApiException catch (e) {
      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      AppToast.error(
        context,
        e.code == LoyaltyErrors.giftUnavailable
            ? l.rewardGiftUnavailable
            : e.messageFor(locale) ?? l.rewardClaimFailed,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, l.rewardClaimFailed);
    } finally {
      if (mounted) setState(() => _busyGrant = null);
    }
  }

  Future<void> _release(Grant grant) async {
    setState(() => _busyGrant = grant.id);
    try {
      await ref.read(cartControllerProvider.notifier).releaseGrant(grant.id);
      invalidateLoyalty(ref);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, L.of(context).rewardClaimFailed);
    } finally {
      if (mounted) setState(() => _busyGrant = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rewards = ref.watch(loyaltyRewardsProvider);
    final balance = ref.watch(pawsBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.rewardsTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(child: PawsPill(paws: balance, compact: true)),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(loyaltyRewardsProvider);
          await ref.read(loyaltyRewardsProvider.future);
        },
        child: AsyncView<RewardsCatalog>(
          value: rewards,
          onRetry: () => ref.invalidate(loyaltyRewardsProvider),
          skeleton: const _RewardsSkeleton(),
          builder: (data) => _body(context, data, balance),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, RewardsCatalog data, int balance) {
    final l = L.of(context);
    final grants = [...data.activeGrants, ...data.pendingGrants];
    // A gift with no product behind it is the owner's unfinished work, not
    // the customer's problem: it never reaches the shelf.
    final catalog = data.catalog
        .where((reward) => reward.isPurchasable && !(reward.isGift && reward.product == null))
        .toList();

    if (grants.isEmpty && catalog.isEmpty) {
      return EmptyState(
        icon: Icons.card_giftcard_rounded,
        title: l.rewardsEmpty,
        message: l.rewardsEmptyHint,
        mascot: true,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (grants.isNotEmpty) ...[
          SectionHeader(title: l.rewardsMine, padding: EdgeInsets.zero),
          Gap.h12,
          for (final grant in grants) ...[
            GrantCard(
              grant: grant,
              busy: _busyGrant == grant.id,
              onUse: grant.isClaimable ? () => _claim(grant) : null,
              onRemove: grant.isClaimed ? () => _release(grant) : null,
            ),
            Gap.h12,
          ],
          Gap.h12,
        ],
        if (catalog.isNotEmpty) ...[
          SectionHeader(title: l.rewardsCatalog, padding: EdgeInsets.zero),
          Gap.h12,
          for (final reward in catalog) ...[
            RewardCard(
              reward: reward,
              balance: balance,
              onRedeem: _redeeming ? null : () => _redeem(reward),
            ),
            Gap.h12,
          ],
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.rewardsCatalogEmpty,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _RewardsSkeleton extends StatelessWidget {
  const _RewardsSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 150, radius: ZbTokens.rXl),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 150, radius: ZbTokens.rXl),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 150, radius: ZbTokens.rXl),
          ],
        ),
      );
}
