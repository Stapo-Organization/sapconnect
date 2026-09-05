import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'reward_card.dart';
import 'reward_glyph.dart';

/// A reward this customer already holds.
///
/// Three states, three sentences: waiting on a delivery, ready to carry into
/// the cart, or already in it. The waiting state is the important one — the
/// program's whole promise is "on delivery", and a card that hid that would be
/// the first place the promise looked like a trick.
class GrantCard extends StatelessWidget {
  const GrantCard({
    super.key,
    required this.grant,
    this.onUse,
    this.onRemove,
    this.busy = false,
  });

  final Grant grant;

  /// Claims it into the cart. Null hides the action (a pending grant).
  final Future<void> Function()? onUse;

  /// Releases the claim. Null when it isn't in the cart.
  final Future<void> Function()? onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;
    final reward = grant.reward;
    final pendingOrder = grant.activatesOnOrder;

    final status = grant.isPending
        ? (pendingOrder == null
            ? l.rewardPending
            : l.rewardPendingOrder(pendingOrder.number))
        : (grant.expiresAt != null
            ? l.rewardExpires(Fmt.dateShort(grant.expiresAt!, locale))
            : null);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(
          color: grant.isClaimed ? cs.primary.withValues(alpha: 0.45) : cs.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RewardGlyphWell(kind: reward.kind),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rewardKindLabel(l, reward.kind),
                  style: context.tt.labelSmall?.copyWith(
                    color: rewardKindTint(context, reward.kind),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap.h4,
                Text(
                  reward.title,
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (status != null) ...[
                  Gap.h4,
                  Row(
                    children: [
                      Icon(
                        grant.isPending
                            ? Icons.schedule_rounded
                            : Icons.event_available_rounded,
                        size: 14,
                        color: grant.isPending ? zb.warning : cs.onSurfaceVariant,
                      ),
                      Gap.w4,
                      Expanded(
                        child: Text(
                          status,
                          style: context.tt.labelSmall?.copyWith(
                            color: grant.isPending ? zb.warning : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onUse != null || onRemove != null) ...[
                  Gap.h12,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : grant.isClaimed
                            ? TextButton.icon(
                                onPressed: onRemove == null ? null : () => onRemove!(),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: Text(l.rewardRemove),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.onSurfaceVariant,
                                ),
                              )
                            : FilledButton.tonal(
                                onPressed: onUse == null ? null : () => onUse!(),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 38),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                ),
                                child: Text(l.rewardUseInCart),
                              ),
                  ),
                ] else if (grant.isClaimed) ...[
                  Gap.h8,
                  Text(
                    l.rewardInCart,
                    style: context.tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
