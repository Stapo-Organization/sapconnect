import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../data/pet_models.dart';
import '../../loyalty/data/loyalty_models.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../data/pets_repository.dart';
import '../../loyalty/presentation/widgets/loyalty_art.dart';
import 'widgets/pet_card.dart';

/// «عائلتي» — the pets on file.
///
/// This is the emotional anchor of the whole program: everything downstream
/// (the food counter, the birthday gift, the species missions) is only as good
/// as what is on this screen, so adding a pet is one tap from anywhere here.
class PetsScreen extends ConsumerWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final signedIn = ref.watch(isAuthenticatedProvider);
    final pets = ref.watch(petsProvider);

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.petsTitle)),
        body: EmptyState(
          icon: Icons.pets_rounded,
          title: l.familyGuestTitle,
          message: l.familyGuestBody,
          actionLabel: l.familyGuestCta,
          onAction: () => showAuthSheet(context, reason: l.familyGuestBody),
          mascot: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.petsTitle)),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(petsProvider),
        child: AsyncView<PetsPayload>(
          value: pets,
          onRetry: () => ref.invalidate(petsProvider),
          skeleton: const _PetsSkeleton(),
          builder: (data) => _Loaded(
            data: data,
            supply: ref.watch(loyaltySummaryProvider).value?.supply.items ?? const [],
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.data, this.supply = const []});

  final PetsPayload data;

  /// The gauge's lines, so each card can say when its pet's food runs out.
  final List<SupplyItem> supply;

  SupplyItem? _supplyFor(Pet pet) {
    for (final item in supply) {
      if (item.pet?.id == pet.id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    if (data.pets.isEmpty) {
      return EmptyState(
        icon: Icons.pets_rounded,
        title: l.petsEmpty,
        message: l.petsEmptyHint,
        actionLabel: l.petsAdd,
        onAction: () => context.push('/pets/new'),
        mascot: true,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final pet in data.pets) ...[
          PetCard(pet: pet, supply: _supplyFor(pet), onTap: () => context.push('/pets/${pet.id}', extra: pet)),
          Gap.h12,
        ],
        if (data.canAdd)
          _AddPetTile(onTap: () => context.push('/pets/new'))
        else
          Text(
            l.petsFull(data.max),
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _PetsSkeleton extends StatelessWidget {
  const _PetsSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: const [
            SkeletonBox(width: double.infinity, height: 92, radius: ZbTokens.rLg),
            Gap.h12,
            SkeletonBox(width: double.infinity, height: 92, radius: ZbTokens.rLg),
          ],
        ),
      );
}

/// The dashed "add a friend" tile — one tap, with the paws it pays.
class _AddPetTile extends StatelessWidget {
  const _AddPetTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: context.isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: context.isDark ? 0.18 : 0.12),
              ),
              alignment: Alignment.center,
              child: FamilyMarkIcon(FamilyMark.plus, size: 26, color: cs.primary),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.petsAdd,
                    style: context.tt.titleSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap.h4,
                  Row(
                    children: [
                      const PawCoin(size: 16),
                      Gap.w4,
                      Expanded(
                        child: Text(
                          l.pawsHowPet,
                          style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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
    );
  }
}
