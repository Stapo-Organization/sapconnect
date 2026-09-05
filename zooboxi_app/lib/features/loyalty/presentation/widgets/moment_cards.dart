import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/sparkles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/presentation/widgets/species_avatar.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// «عيد ميلاد مشمش» — the pet's portrait, the day, and the gift the program
/// put in the wallet, with the one button that carries it to the basket.
class BirthdayCard extends StatelessWidget {
  const BirthdayCard({super.key, required this.moment, this.onClaim, this.onTap, this.busy = false});

  final BirthdayMoment moment;
  final VoidCallback? onClaim;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final pet = moment.pet;
    final days = moment.days;
    final when = days == 0 ? l.momentBirthdayToday : (days > 0 ? l.momentBirthdayIn(days) : l.momentBirthdayPassed(-days));
    final grant = moment.grant;

    final body = grant != null
        ? l.momentBirthdayGift
        : (moment.paws != null ? l.momentBirthdayPaws(Fmt.number(moment.paws!, locale: locale, decimals: 0)) : l.momentBirthdayNoGift);

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: context.isDark
                ? [const Color(0xFF3A2A30), const Color(0xFF2A2226)]
                : [const Color(0xFFFFEFEA), const Color(0xFFFFF8F1)],
          ),
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: ZbTokens.logoCoral.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: SparkleField(sparkles: _sparkles, twinkle: true)),
            const PositionedDirectional(
              end: -24,
              top: -14,
              width: 140,
              height: 100,
              child: PawPattern(color: ZbTokens.logoCoral, opacity: 0.10, scale: 0.7),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SpeciesAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 60, ring: Colors.white),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FamilyMarkIcon(FamilyMark.cake, size: 20),
                            Gap.w6,
                            Expanded(
                              child: Text(
                                l.momentBirthdayTitle(pet.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Gap.w8,
                            Text(
                              when,
                              style: context.tt.labelSmall?.copyWith(color: ZbTokens.logoCoral, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Gap.h4,
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (grant != null && grant.isClaimable && onClaim != null) ...[
                          Gap.h8,
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FilledButton.icon(
                              onPressed: busy ? null : onClaim,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                backgroundColor: ZbTokens.logoCoral,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              icon: const RewardSticker(kind: 'gift_product', size: 18),
                              label: Text(l.momentAddToCart),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<SparkleSpec> _sparkles = [
  SparkleSpec(dx: 0.86, dy: 0.20, size: 12, color: ZbTokens.sparkAmber, delay: Duration(milliseconds: 200)),
  SparkleSpec(dx: 0.95, dy: 0.66, size: 8, color: ZbTokens.logoCoral, delay: Duration(milliseconds: 800), rotation: 0.4),
  SparkleSpec(dx: 0.66, dy: 0.86, size: 7, color: ZbTokens.logoTeal, delay: Duration(milliseconds: 1200), rotation: 0.2),
];

/// «طلب واحد يحفظ مستواك» — the soft drop, on the tier card's stub.
class TierRiskLine extends StatelessWidget {
  const TierRiskLine({super.key, required this.risk, required this.accent});

  final TierRisk risk;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final name = risk.wouldDropToName.isNotEmpty
        ? risk.wouldDropToName
        : (TierRung.byKey(risk.wouldDropTo)?.name(Localizations.localeOf(context).languageCode) ?? risk.wouldDropTo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZbTokens.amber.withValues(alpha: context.isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
      ),
      child: Row(
        children: [
          const FamilyMarkIcon(FamilyMark.clock, size: 18),
          Gap.w8,
          Expanded(
            child: Text(
              l.tierRiskLine(risk.inDays, name),
              style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The referral card on the hub: the code, the promise, one share button.
class ReferralCard extends StatelessWidget {
  const ReferralCard({super.key, required this.referral, this.onShare, this.onOpen});

  final ReferralSummary referral;
  final VoidCallback? onShare;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return PressScale(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const PositionedDirectional(
              end: -20,
              bottom: -30,
              width: 150,
              height: 110,
              child: PawPattern(color: ZbTokens.logoTeal, opacity: 0.10, scale: 0.7),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const FamilyMarkIcon(FamilyMark.share, size: 44),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.referralTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Gap.h4,
                        Text(
                          l.referralHubBody(Fmt.number(referral.rewardPaws, locale: locale, decimals: 0)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Gap.h8,
                        Row(
                          children: [
                            Flexible(child: _CodePill(code: referral.code)),
                            Gap.w8,
                            Flexible(
                              child: FilledButton(
                                onPressed: onShare,
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                                child: Text(l.referralShare, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ZbTokens.logoTeal.withValues(alpha: context.isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
          border: Border.all(color: ZbTokens.logoTeal.withValues(alpha: 0.4)),
        ),
        child: Text(
          code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: context.tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: context.isDark ? ZbTokens.creamLogo : ZbTokens.tealDeep,
          ),
        ),
      );
}

/// A brand's stamp card: the row of paw stamps, the reward at the end.
class StampCardView extends StatelessWidget {
  const StampCardView({super.key, required this.card});

  final StampCard card;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final total = card.unitsRequired.clamp(1, 12);
    final filled = (card.units * total / card.unitsRequired).floor().clamp(0, total);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FamilyMarkIcon(FamilyMark.tag, size: 28),
              Gap.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      [
                        if (card.brandName.isNotEmpty) card.brandName,
                        if (card.minPackKg > 0) l.stampsMinPack(Fmt.number(card.minPackKg, locale: locale, decimals: 1)),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                l.stampsRemaining(card.remaining),
                style: context.tt.labelMedium?.copyWith(color: ZbTokens.amberDeep, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Gap.h12,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < filled ? ZbTokens.amber.withValues(alpha: 0.9) : cs.surfaceContainerHighest,
                    border: Border.all(color: i < filled ? ZbTokens.amberDeep : cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: i < filled ? const FamilyMarkIcon(FamilyMark.family, size: 16, color: Colors.white) : null,
                ),
              if (card.reward != null)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: RewardSticker(kind: card.reward!.kind, size: 30),
                ),
            ],
          ),
          if (card.reward != null || card.cyclesDone > 0) ...[
            Gap.h8,
            Text(
              [
                if (card.reward != null) '${l.stampsReward}: ${card.reward!.title}',
                if (card.cyclesDone > 0) l.stampsDone(card.cyclesDone),
              ].join(' · '),
              style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
