import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'paws_pill.dart';

/// Standing, at the top of the family hub.
///
/// The tier's two hues paint a band across the head of the card — the one
/// place a tier is allowed to bring its own colour — and everything below it
/// stays on the app's surface so the perks read as facts, not as decoration.
/// The bar is drawn from delivered orders, the same number printed under it.
class TierCard extends StatelessWidget {
  const TierCard({super.key, required this.tier, required this.paws, this.onPawsTap});

  final TierInfo tier;
  final PawsBalance paws;
  final VoidCallback? onPawsTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final (start, end) = TierChip.colorsOf(context, tier.c1, tier.c2);
    final next = tier.next;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [start, end],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.name.isEmpty ? l.familyTitle : tier.name,
                        style: context.tt.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        l.familyTierOrders(tier.orders12m),
                        style: context.tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.w12,
                PawsPill(
                  paws: paws.balance,
                  onTap: onPawsTap,
                  foreground: Colors.white,
                  background: Colors.white.withValues(alpha: 0.22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: tier.progress),
                    duration: context.motion(const Duration(milliseconds: 620)),
                    curve: Motion.emphasized,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(end),
                    ),
                  ),
                ),
                Gap.h8,
                Text(
                  next == null
                      ? l.familyTierTop
                      : l.familyTierNext(tier.ordersToNext, next.name),
                  style: context.tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tier.perks.isNotEmpty) ...[
                  Gap.h16,
                  Text(
                    l.familyPerksTitle,
                    style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Gap.h8,
                  for (final perk in tier.perks)
                    _PerkRow(perk: perk, accent: end),
                ],
                if (paws.pending > 0) ...[
                  Gap.h12,
                  _PendingNote(
                    text: l.pawsPending(
                      Fmt.number(paws.pending, locale: locale, decimals: 0),
                    ),
                    hint: l.pawsPendingHint,
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

/// One perk. Never worded by the app — the store owns the copy and whether it
/// is live, so a threshold change never needs a release to stay honest here.
class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.perk, required this.accent});

  final TierPerk perk;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final active = perk.active;
    final from = perk.fromTier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: active
                ? Icon(Icons.check_circle_rounded, size: 17, color: accent)
                : Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
          ),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perk.text,
                  style: context.tt.bodyMedium?.copyWith(
                    color: active ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                if (!active && from != null && from.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      l.familyPerkFrom(from),
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paws that exist but haven't landed: revealed prizes on orders still out for
/// delivery. Saying so is the whole point — the rule is "on delivery".
class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.text, required this.hint});

  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
      ),
      child: Row(
        children: [
          ZbIcon(ZbIconKind.paw, size: 16, fill: 1, tint: cs.onSurfaceVariant),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  hint,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
