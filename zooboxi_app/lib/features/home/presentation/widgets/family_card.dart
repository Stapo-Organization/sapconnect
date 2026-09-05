import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/icons/zb_icons.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_sheet.dart';
import '../../../cart/presentation/add_to_cart.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/data/product_models.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/presentation/widgets/paws_pill.dart';
import '../../../pets/data/pet_models.dart';
import '../../../pets/presentation/widgets/species_avatar.dart';

/// Which face the card is wearing. Reported as the `family_card` event's
/// payload, because "which variant did they see" is the only way to read
/// whether the card is doing anything.
enum FamilyCardVariant { guest, noPet, due, mission, tier }

/// The storefront's window into «عائلة زوبوكسي».
///
/// One card, four things it can be saying, in strict order of usefulness: a
/// guest gets an invitation; a member with no pet on file gets the same
/// invitation with their balance attached; a member whose food is running out
/// gets the reorder and a button that does it; everyone else gets the nearest
/// mission, or their standing.
///
/// It renders only when the server ships the `family` slot, and it never
/// blocks the storefront: with no summary — a failed call, a slow one, the
/// program switched off — the card simply does not draw.
class FamilyCard extends ConsumerStatefulWidget {
  const FamilyCard({super.key, required this.summary, this.feed});

  final LoyaltySummary? summary;
  final HomeFeed? feed;

  /// The variant this data resolves to, exposed so Home (and the tests) can
  /// reason about the card without rebuilding its logic.
  static FamilyCardVariant variantOf(LoyaltySummary? summary, HomeFeed? feed) {
    if (summary == null) return FamilyCardVariant.guest;
    if (summary.pets.isEmpty) return FamilyCardVariant.noPet;
    if (dueProduct(feed) != null) return FamilyCardVariant.due;
    if (summary.playsGames && summary.missions.nearest != null) {
      return FamilyCardVariant.mission;
    }
    return FamilyCardVariant.tier;
  }

  /// The first product the feed says this customer is due to run out of.
  static ProductCard? dueProduct(HomeFeed? feed) {
    final personal = feed?.personal;
    if (personal == null || personal.isEmpty || !personal.anyDue) return null;
    for (final product in personal.products) {
      if (personal.hints[product.id]?.due ?? false) return product;
    }
    return null;
  }

  @override
  ConsumerState<FamilyCard> createState() => _FamilyCardState();
}

class _FamilyCardState extends ConsumerState<FamilyCard> {
  FamilyCardVariant? _tracked;
  bool _adding = false;

  void _track(FamilyCardVariant variant) {
    if (_tracked == variant) return;
    _tracked = variant;
    ref.read(eventsBufferProvider).track(
          ZbEvent(
            type: ZbEvents.familyCard,
            zone: 'home',
            payload: {'variant': variant.name},
          ),
        );
  }

  Future<void> _signInThenAddPet() async {
    final signedIn = await showAuthSheet(
      context,
      reason: L.of(context).familyGuestBody,
    );
    if (!signedIn || !mounted) return;
    await context.push<void>('/pets/new');
  }

  Future<void> _reorder(ProductCard product) async {
    if (_adding) return;
    setState(() => _adding = true);
    await addToCart(context, ref, product: product, zone: 'home_family');
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final variant = FamilyCard.variantOf(summary, widget.feed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _track(variant);
    });

    final body = switch (variant) {
      FamilyCardVariant.guest => _Invitation(
          paws: null,
          onTap: _signInThenAddPet,
        ),
      FamilyCardVariant.noPet => _Invitation(
          paws: summary!.paws.balance,
          onTap: () => context.push('/pets/new'),
        ),
      FamilyCardVariant.due => _PetRow(
          pet: summary!.firstPet!,
          onTap: () => context.push('/family'),
          child: _DueLine(
            product: FamilyCard.dueProduct(widget.feed)!,
            busy: _adding,
            onOrder: () => _reorder(FamilyCard.dueProduct(widget.feed)!),
          ),
        ),
      FamilyCardVariant.mission => _PetRow(
          pet: summary!.firstPet!,
          onTap: () => context.push('/family'),
          child: _MissionLine(mission: summary.missions.nearest!),
        ),
      FamilyCardVariant.tier => _PetRow(
          pet: summary!.firstPet!,
          onTap: () => context.push('/family'),
          child: _StandingLine(summary: summary),
        ),
    };

    return body;
  }
}

/// The shell every variant sits in: one surface, the same radius and border as
/// the cards on either side of it.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final card = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );

    if (onTap == null) return card;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: card,
    );
  }
}

/// Guest, and member-with-no-pet: the same ask, one with a balance attached.
class _Invitation extends StatelessWidget {
  const _Invitation({required this.onTap, this.paws});

  final VoidCallback onTap;
  final int? paws;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final balance = paws;

    return _Shell(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: context.isDark ? 0.20 : 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ZbIcon(ZbIconKind.paw, size: 28, fill: 1, tint: cs.primary),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        balance == null ? l.familyGuestTitle : l.familyNoPetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (balance != null && balance > 0) ...[
                      Gap.w8,
                      PawsPill(paws: balance, compact: true, showUnit: false),
                    ],
                  ],
                ),
                Gap.h4,
                Text(
                  balance == null ? l.familyGuestBody : l.familyNoPetBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Gap.h12,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonal(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(balance == null ? l.familyGuestCta : l.familyAddPet),
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

/// The three member variants share a portrait and a name; only the line under
/// the name changes.
class _PetRow extends StatelessWidget {
  const _PetRow({required this.pet, required this.child, this.onTap});

  final Pet pet;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpeciesAvatar(species: pet.species, size: 56),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.h4,
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Time to reorder X" — the single most useful sentence the program can put
/// on the storefront, with the button that finishes it.
class _DueLine extends StatelessWidget {
  const _DueLine({required this.product, required this.onOrder, this.busy = false});

  final ProductCard product;
  final VoidCallback onOrder;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.familyDue(product.name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Gap.h12,
        Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: ZbImage(
                url: product.image,
                radius: BorderRadius.circular(ZbTokens.rXs),
                padding: const EdgeInsets.all(3),
              ),
            ),
            Gap.w8,
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onOrder,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.familyOrderNow),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The nearest open mission, with the bar that says how close it is.
class _MissionLine extends StatelessWidget {
  const _MissionLine({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mission.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Gap.h8,
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: mission.ratio),
                  duration: context.motion(const Duration(milliseconds: 560)),
                  curve: Motion.emphasized,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
            ),
            Gap.w8,
            Text(
              l.missionProgress(mission.progress, mission.target),
              style: context.tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The quiet fallback: where they stand and what they hold.
class _StandingLine extends StatelessWidget {
  const _StandingLine({required this.summary});

  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    final tier = summary.tier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tier.next == null
              ? L.of(context).familyTierTop
              : L.of(context).familyTierNext(tier.ordersToNext, tier.next!.name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
        ),
        Gap.h8,
        // Wrapped, not a Row: a long tier name at a large text size plus a
        // five-figure balance is exactly the pair that would run off the end.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            TierChip(label: tier.name, c1: tier.c1, c2: tier.c2, compact: true),
            PawsPill(paws: summary.paws.balance, compact: true),
          ],
        ),
      ],
    );
  }
}
