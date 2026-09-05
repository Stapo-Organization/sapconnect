import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../data/pet_models.dart';
import '../data/pets_repository.dart';
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
          builder: (data) => _Loaded(data: data),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.data});

  final PetsPayload data;

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
          PetCard(pet: pet, onTap: () => context.push('/pets/${pet.id}', extra: pet)),
          Gap.h12,
        ],
        Gap.h8,
        if (data.canAdd)
          OutlinedButton.icon(
            onPressed: () => context.push('/pets/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.petsAdd),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          )
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
