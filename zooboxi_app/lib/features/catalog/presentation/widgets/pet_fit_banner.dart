import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/household.dart';
import '../../../pets/data/pet_models.dart';
import '../../data/catalog_models.dart';
import '../../data/pet_fit.dart';

/// «نعرض المناسب لـ مشمش» — the pet's own filter, one switch away.
///
/// Every competitor keeps the pet profile for recommendations; here it is a
/// filter: the life stage the store's facets understand, taken from the
/// pet's birth date (or a one-tap answer when there is none), applied the
/// moment a food aisle opens, and said out loud so nothing is hidden
/// silently — the switch and «عرض الكل» are right there.
class PetFitBanner extends StatelessWidget {
  const PetFitBanner({
    super.key,
    required this.fit,
    required this.active,
    required this.lifeGroup,
    required this.onToggle,
    required this.onAnswer,
  });

  final PetFit fit;
  final bool active;

  /// The listing's «العمر» facet — labels for the answer chips and the badge.
  final FacetGroup? lifeGroup;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onAnswer;

  static String nameOf(L l, PetFit fit) {
    if (fit.name.isNotEmpty) return fit.name;
    return switch (fit.species) {
      PetSpecies.cat => l.petYourCat,
      PetSpecies.dog => l.petYourDog,
      _ => l.petYourPet,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final locale = Localizations.localeOf(context).languageCode;
    final name = nameOf(l, fit);
    final cast = castForSpecies(fit.species) ?? ZbCast.cat;
    final bg = dark ? ZbTokens.tealContainerDark : ZbTokens.teal;
    const onBg = Colors.white;
    final soft = dark ? ZbTokens.inkSoftDark : ZbTokens.tealTint;
    final knowsAge = fit.life != null;

    final facts = <String>[
      if (knowsAge) lifeGroup?.labelOf(fit.life!) ?? '',
      if (fit.weightKg != null && fit.weightKg! > 0)
        '${Fmt.number(fit.weightKg!, locale: locale, decimals: 1)} ${locale == 'ar' ? 'كجم' : 'kg'}',
    ].where((s) => s.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: active || !knowsAge ? bg : (dark ? ZbTokens.graphiteHigh : ZbTokens.tealTintSoft),
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
        ),
        child: Row(
          children: [
            // The pet itself, on a white plate — the same cast member the
            // household picked in onboarding.
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.bottomCenter,
              child: ZbSticker.cast(cast, ZbPose.sitUp, height: 60, idle: ZbIdle.none, entrance: false),
            ),
            Gap.w12,
            Expanded(
              child: knowsAge
                  ? _Known(
                      kicker: active ? l.petFilterKicker : l.petFilterOff,
                      name: name,
                      facts: facts,
                      onBg: active ? onBg : context.cs.onSurface,
                      soft: active ? soft : context.cs.onSurfaceVariant,
                      chipBg: active ? Colors.white.withValues(alpha: 0.2) : context.cs.surface,
                    )
                  : _Ask(
                      question: l.petAskAge(name),
                      hint: l.petAskAgeHint,
                      values: lifeGroup?.values ?? const [],
                      soft: soft,
                      onAnswer: (life) {
                        Haptics.light();
                        onAnswer(life);
                      },
                    ),
            ),
            if (knowsAge) ...[
              Gap.w8,
              Semantics(
                label: l.petFilterSwitch(name),
                child: Switch.adaptive(
                  value: active,
                  onChanged: (v) {
                    Haptics.selection();
                    onToggle(v);
                  },
                  activeTrackColor: Colors.white,
                  activeThumbColor: ZbTokens.tealDeep,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Known extends StatelessWidget {
  const _Known({
    required this.kicker,
    required this.name,
    required this.facts,
    required this.onBg,
    required this.soft,
    required this.chipBg,
  });

  final String kicker;
  final String name;
  final List<String> facts;
  final Color onBg;
  final Color soft;
  final Color chipBg;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kicker, style: context.tt.bodySmall?.copyWith(color: soft, fontWeight: FontWeight.w600)),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.titleLarge?.copyWith(color: onBg, fontWeight: FontWeight.w800, height: 1.2),
          ),
          if (facts.isNotEmpty) ...[
            Gap.h4,
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final f in facts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(ZbTokens.rPill)),
                    child: Text(f, style: context.tt.labelSmall?.copyWith(color: onBg, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ],
      );
}

class _Ask extends StatelessWidget {
  const _Ask({
    required this.question,
    required this.hint,
    required this.values,
    required this.soft,
    required this.onAnswer,
  });

  final String question;
  final String hint;
  final List<FacetValue> values;
  final Color soft;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(question, style: context.tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          Text(hint, style: context.tt.bodySmall?.copyWith(color: soft)),
          Gap.h8,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in values.where((v) => v.count > 0 || v.selected))
                Material(
                  color: Colors.white,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onAnswer(v.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        v.label,
                        style: context.tt.labelLarge?.copyWith(color: ZbTokens.tealDeep, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
}
