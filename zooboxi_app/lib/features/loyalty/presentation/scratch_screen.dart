import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import 'widgets/scratch_card_view.dart';

/// One scratch card, opened from the family hub.
///
/// The card is fetched rather than passed so a deep link works and so a card
/// already revealed on another device opens showing its prize instead of a
/// foil that would come off onto nothing.
class ScratchScreen extends ConsumerWidget {
  const ScratchScreen({super.key, required this.cardId, this.initial});

  final int cardId;

  /// The card the caller already held, so the foil is on screen immediately.
  final ScratchCard? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cards = ref.watch(scratchCardsProvider);
    final known = initial;

    return Scaffold(
      appBar: AppBar(title: Text(l.scratchTitle)),
      body: SafeArea(
        child: AsyncView<List<ScratchCard>>(
          value: known != null
              ? AsyncValue.data(cards.value ?? [known])
              : cards,
          onRetry: () => ref.invalidate(scratchCardsProvider),
          skeleton: const _ScratchSkeleton(),
          builder: (data) {
            final card = data.where((entry) => entry.id == cardId).firstOrNull ?? known;
            if (card == null) {
              return EmptyState(
                icon: Icons.style_rounded,
                title: l.scratchEmpty,
                message: l.scratchEmptyHint,
                actionLabel: l.actionClose,
                onAction: () => context.pop(),
                mascot: true,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  l.scratchTitle,
                  textAlign: TextAlign.center,
                  style: context.tt.headlineSmall,
                ),
                Gap.h8,
                Text(
                  card.order == null
                      ? l.scratchHint
                      : l.scratchOrder(card.order!.number),
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium
                      ?.copyWith(color: context.cs.onSurfaceVariant),
                ),
                Gap.h24,
                ScratchCardView(
                  card: card,
                  onDone: () => context.pop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScratchSkeleton extends StatelessWidget {
  const _ScratchSkeleton();

  @override
  Widget build(BuildContext context) => const ShimmerGroup(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            children: [
              SkeletonBox(width: 180, height: 22),
              Gap.h24,
              SkeletonBox(width: double.infinity, height: 210, radius: ZbTokens.rXl),
            ],
          ),
        ),
      );
}
