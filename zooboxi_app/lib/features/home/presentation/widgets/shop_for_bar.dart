import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../pets/data/household.dart';
import '../../../pets/data/pet_models.dart';
import '../../../pets/presentation/widgets/pet_card.dart' show speciesLabel;
import '../../../pets/presentation/widgets/species_avatar.dart';

/// «تسوّق لـ» — which of the family the page is arranged for. Only for a
/// household of two or more: with one animal there is nothing to choose.
class ShopForBar extends ConsumerWidget {
  const ShopForBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider);
    if (household.members.length < 2) return const SizedBox.shrink();
    final l = L.of(context);
    final cs = context.cs;
    final notifier = ref.read(householdProvider.notifier);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        children: [
          Center(
            child: Text(
              l.shopForLabel,
              style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: l.shopForAll,
            selected: household.shoppingFor == null,
            onTap: () => notifier.shopFor(null),
          ),
          for (var i = 0; i < household.members.length; i++) ...[
            const SizedBox(width: 8),
            _Chip(
              label: household.members[i].name.isNotEmpty
                  ? household.members[i].name
                  : speciesLabel(l, household.members[i].species),
              species: household.members[i].species,
              selected: household.shoppingFor == household.members[i].keyAt(i),
              onTap: () => notifier.shopFor(household.members[i].keyAt(i)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.species});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PetSpecies? species;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primary : cs.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? cs.primary : cs.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (selected) return;
            Haptics.selection();
            onTap();
          },
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(species == null ? 14 : 5, 4, 14, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (species != null) ...[SpeciesAvatar(species: species!, size: 30), const SizedBox(width: 7)],
                Text(label, style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
