import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/providers.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/household.dart';
import '../../../pets/data/pet_models.dart';
import '../../../pets/data/pets_repository.dart';
import '../../../pets/presentation/weight_sheet.dart';

/// «الاستراحة» that finishes a profile: a cat or dog on file without a weight
/// is asked for one — in its own card between the rails, never in a form.
/// «ما أعرف الحين» rests the ask for two weeks.
class WeightNudge extends ConsumerWidget {
  const WeightNudge({super.key, required this.pet});

  final Pet pet;

  static const Duration _rest = Duration(days: 14);

  /// The pet to ask about, if any.
  static Pet? candidate(WidgetRef ref) {
    if (!ref.watch(isAuthenticatedProvider)) return null;
    final pets = ref.watch(petsProvider).value?.pets ?? const <Pet>[];
    for (final pet in pets) {
      if (pet.weightKg != null || !pet.isSaved) continue;
      if (pet.species != PetSpecies.cat && pet.species != PetSpecies.dog) continue;
      try {
        final dismissed = ref.read(localStoreProvider).weightNudgeDismissed(pet.id);
        if (dismissed != null && DateTime.now().difference(dismissed) < _rest) continue;
      } catch (_) {
        return null;
      }
      return pet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final cast = castForSpecies(pet.species) ?? ZbCast.cat;
    const sitter = 112.0;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: PressScale(
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
              onTap: () => showWeightSheet(context, ref, pet),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: context.isDark ? cs.surfaceContainerHigh : ZbTokens.tealTintSoft,
                  borderRadius: BorderRadius.circular(ZbTokens.rXl),
                  border: Border.all(color: context.isDark ? cs.outlineVariant : ZbTokens.tealTint),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: sitter * 0.72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.weightNudgeTitle(pet.name),
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(l.weightNudgeBody, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          l.weightNudgeCta,
                          style: context.tt.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 18,
            bottom: 6,
            child: Companion(ZbPose.sitUp, cast: cast, height: sitter, flip: !context.isRtl),
          ),
        ],
      ),
    );
  }
}
