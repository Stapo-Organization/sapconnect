import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/pet_models.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import 'species_avatar.dart';

/// The Arabic (and English) name of a species.
String speciesLabel(L l, PetSpecies species) => switch (species) {
      PetSpecies.cat => l.petSpeciesCat,
      PetSpecies.dog => l.petSpeciesDog,
      PetSpecies.bird => l.petSpeciesBird,
      PetSpecies.fish => l.petSpeciesFish,
      PetSpecies.small => l.petSpeciesSmall,
      PetSpecies.reptile => l.petSpeciesReptile,
      PetSpecies.other => l.petSpeciesOther,
    };

/// One animal in the family list.
///
/// The card leads with the portrait because that is what the customer
/// recognises, and the second line is the three facts the store actually uses:
/// species, breed and age. An incomplete profile gets one quiet nudge with the
/// reward attached — never a red warning, because a missing weight is not an
/// error, it is an opportunity.
class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.pet, this.onTap});

  final Pet pet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    final facts = <String>[
      speciesLabel(l, pet.species),
      if (pet.breed.isNotEmpty) pet.breed,
      if ((pet.ageLabel ?? '').isNotEmpty) pet.ageLabel!,
      if (pet.weightKg != null)
        '${Fmt.number(pet.weightKg!, locale: locale, decimals: 1)} ${l.petWeightUnit}',
    ];
    final art = SpeciesArt.of(pet.species);

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: art.shade.withValues(alpha: context.isDark ? 0 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SpeciesAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 70),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap.h8,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // The birthday leads the facts: it is the one with a date on it.
                      if (pet.isBirthdaySoon) _BirthdayChip(days: pet.birthdayInDays ?? 0),
                      for (final fact in facts) _FactChip(text: fact, tint: art.well, ink: art.shade),
                    ],
                  ),
                  if (!pet.isComplete) ...[
                    Gap.h8,
                    Row(
                      children: [
                        const PawCoin(size: 16),
                        Gap.w4,
                        Expanded(
                          child: Text(
                            l.petIncompleteHint,
                            style: context.tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
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

class _BirthdayChip extends StatelessWidget {
  const _BirthdayChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final zb = context.zb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: zb.sale.withValues(alpha: context.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        L.of(context).petBirthdaySoon(days),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.tt.labelSmall?.copyWith(
          color: zb.sale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One fact about the pet, on the species' own wash.
class _FactChip extends StatelessWidget {
  const _FactChip({required this.text, required this.tint, required this.ink});

  final String text;
  final Color tint;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? ink.withValues(alpha: 0.22) : tint,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        text,
        style: context.tt.labelSmall?.copyWith(
          color: dark ? context.cs.onSurface : Color.lerp(ink, ZbTokens.ink, 0.45),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
