import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/pet_models.dart';
import '../../../pets/presentation/widgets/species_avatar.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';
import 'paws_pill.dart';

/// The membership card — standing, wallet and the ladder, as one object.
///
/// The tier's two hues paint the card itself (the one place a tier is allowed
/// to bring its own colour), textured with the paw pattern so it reads as a
/// printed card rather than a coloured box. The family's first face sits at
/// the top because the program is named after them; the balance counts up on
/// arrival because a number that lands is a number that was earned; and the
/// ladder on the stub shows the whole journey, not just the next rung.
class TierCard extends StatelessWidget {
  const TierCard({
    super.key,
    required this.tier,
    required this.paws,
    this.onPawsTap,
    this.pet,
    this.pendingOrders = const [],
  });

  final TierInfo tier;
  final PawsBalance paws;
  final VoidCallback? onPawsTap;

  /// The first pet on file, for the portrait and the greeting.
  final Pet? pet;

  /// Orders placed but not yet delivered — their paws are on the way.
  final List<PendingOrder> pendingOrders;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final (start, end) = TierChip.colorsOf(context, tier.c1, tier.c2);
    final next = tier.next;
    final pet = this.pet;
    final pendingPaws = paws.pending + pendingOrders.fold<int>(0, (sum, o) => sum + o.paws);

    Widget face = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [start, end],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: PawPattern(opacity: 0.12, scale: 1.1)),
          const Positioned.fill(child: SparkleField(sparkles: _cardSparkles, twinkle: true)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (pet != null)
                      SpeciesAvatar(
                        species: pet.species,
                        photoUrl: pet.photoUrl,
                        size: 58,
                        ring: Colors.white,
                      )
                    else
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: const FamilyMarkIcon(FamilyMark.family, size: 28, color: Colors.white),
                      ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet == null ? l.familyHubGreetingNoPet : l.familyHubGreeting(pet.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: _shadow,
                            ),
                          ),
                          Gap.h4,
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TierTag(name: tier.name.isEmpty ? l.familyTitle : tier.name),
                              Text(
                                l.familyTierOrders(tier.orders12m),
                                style: context.tt.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  shadows: _shadow,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap.h20,
                _Wallet(
                  balance: paws.balance,
                  pending: pendingPaws,
                  onTap: onPawsTap,
                  locale: locale,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!context.reduceMotion) {
      face = face
          .animate()
          .shimmer(
            delay: const Duration(milliseconds: 500),
            duration: const Duration(milliseconds: 1500),
            color: Colors.white.withValues(alpha: 0.28),
            angle: 0.6,
          );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: context.isDark ? 0.18 : 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          face,
          // The stub: the journey.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TierLadder(currentKey: tier.key, progressToNext: tier.progress),
                Gap.h8,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      FamilyMarkIcon(
                        next == null ? FamilyMark.check : FamilyMark.family,
                        size: 18,
                        color: end,
                      ),
                      Gap.w8,
                      Expanded(
                        child: Text(
                          next == null
                              ? l.familyTierTop
                              : l.familyTierNext(tier.ordersToNext, next.name),
                          style: context.tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<Shadow> _shadow = [
    Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 1)),
  ];
}

const List<SparkleSpec> _cardSparkles = [
  SparkleSpec(dx: 0.90, dy: 0.14, size: 14, color: Colors.white, delay: Duration(milliseconds: 300)),
  SparkleSpec(dx: 0.96, dy: 0.42, size: 9, color: Colors.white, delay: Duration(milliseconds: 900), rotation: 0.4),
  SparkleSpec(dx: 0.70, dy: 0.08, size: 8, color: Colors.white, delay: Duration(milliseconds: 1300), rotation: 0.2),
];

/// The tier name in a frosted pill on the card's own colour.
class _TierTag extends StatelessWidget {
  const _TierTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        ),
        child: Text(
          name,
          style: context.tt.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

/// The balance, counted up, with the coin — and the paws still in the air.
class _Wallet extends StatelessWidget {
  const _Wallet({
    required this.balance,
    required this.pending,
    required this.locale,
    this.onTap,
  });

  final int balance;
  final int pending;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final body = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const PawCoin(size: 40),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // A six-figure balance at a large text size still fits:
                    // the number shrinks before it ever pushes the unit out.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: CountUp(
                          value: balance,
                          format: (v) => Fmt.number(v, locale: locale, decimals: 0),
                          style: context.tt.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            shadows: TierCard._shadow,
                          ),
                        ),
                      ),
                    ),
                    Gap.w6,
                    Text(
                      l.pawsUnit,
                      style: context.tt.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  pending > 0
                      ? l.pawsPending(Fmt.number(pending, locale: locale, decimals: 0))
                      : l.pawsWalletTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.85),
            ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

/// The tier's benefits, each with a check or a lock and — when locked — the
/// name of the rung that opens it. The copy is the store's; the app only
/// resolves a bare tier key to its name.
class TierPerks extends StatelessWidget {
  const TierPerks({super.key, required this.perks, required this.accent});

  final List<TierPerk> perks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          for (var i = 0; i < perks.length; i++) ...[
            if (i > 0) Divider(color: cs.outlineVariant.withValues(alpha: 0.7), height: 1),
            _PerkRow(perk: perks[i], accent: accent, locale: locale, l: l),
          ],
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.perk, required this.accent, required this.locale, required this.l});

  final TierPerk perk;
  final Color accent;
  final String locale;
  final L l;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final active = perk.active;
    final rung = TierRung.byKey(perk.fromTier);
    final fromName = perk.fromTierName ?? rung?.name(locale) ?? perk.fromTier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          FamilyMarkIcon(
            active ? FamilyMark.check : FamilyMark.lock,
            size: 24,
            color: active ? accent : (context.isDark ? const Color(0xFF6B6357) : const Color(0xFFC9C1B3)),
          ),
          Gap.w12,
          Expanded(
            child: Text(
              perk.text,
              style: context.tt.bodyMedium?.copyWith(
                color: active ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (!active && fromName != null && fromName.isNotEmpty) ...[
            Gap.w8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (rung?.c2 ?? cs.primary).withValues(alpha: context.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
              ),
              child: Text(
                l.familyPerkFrom(fromName),
                style: context.tt.labelSmall?.copyWith(
                  color: rung?.c2 ?? cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paws that exist but haven't landed — an order on its way. Saying so is the
/// whole point: the rule is "on delivery", and the card that hides that is the
/// first place the promise looks like a trick.
class PendingOrderCard extends StatelessWidget {
  const PendingOrderCard({super.key, required this.order, this.awaitingMission = false});

  final PendingOrder order;

  /// Whether a mission is waiting on this order too.
  final bool awaitingMission;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: context.isDark
              ? [ZbTokens.amberContainerDark, ZbTokens.amberContainerDarkEnd]
              : [ZbTokens.amberTint, ZbTokens.amberTintSoft],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: zb.warning.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const RewardSticker(kind: 'express_free', size: 44),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.familyPendingOrderTitle(order.number),
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h4,
                Text(
                  awaitingMission
                      ? l.familyPendingOrderBody(Fmt.number(order.paws, locale: locale, decimals: 0))
                      : l.familyPendingOrderPaws(Fmt.number(order.paws, locale: locale, decimals: 0)),
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
