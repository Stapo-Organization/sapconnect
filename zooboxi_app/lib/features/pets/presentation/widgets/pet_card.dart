import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/pet_models.dart';
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

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SpeciesAvatar(species: pet.species, size: 62),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (pet.isBirthdaySoon) ...[
                        Gap.w8,
                        // Both halves flex: a long name must not push the
                        // birthday off the card, and a long birthday line must
                        // not push out the name.
                        Flexible(
                          child: _BirthdayChip(days: pet.birthdayInDays ?? 0),
                        ),
                      ],
                    ],
                  ),
                  Gap.h4,
                  Text(
                    facts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (!pet.isComplete) ...[
                    Gap.h8,
                    Text(
                      l.petIncompleteHint,
                      style: context.tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
