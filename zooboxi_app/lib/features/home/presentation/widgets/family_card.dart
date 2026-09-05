import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/mascot_peek.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_sheet.dart';
import '../../../cart/presentation/add_to_cart.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/data/product_models.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../../loyalty/presentation/widgets/paws_pill.dart';
import '../../../pets/data/pet_models.dart';
import '../../../pets/presentation/widgets/species_avatar.dart';

/// Which face the card is wearing. Reported as the `family_card` event's
/// payload, because "which variant did they see" is the only way to read
/// whether the card is doing anything.
enum FamilyCardVariant { guest, noPet, pending, due, mission, tier }

/// The storefront's window into «عائلة زوبوكسي».
///
/// One card, six things it can be saying, in strict order of usefulness: a
/// guest gets an invitation; a member with no pet on file gets the same
/// invitation with their balance attached; a member with an order on its way
/// is told so, with the paws it will pay; a member whose food is running out
/// gets the reorder and the button that does it; everyone else gets the
/// nearest mission, or their standing.
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
    if (summary.pendingOrders.isNotEmpty) return FamilyCardVariant.pending;
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
    // A variable product (sizes, flavours) cannot be added blind — the
    // customer picks the pack on the product page, exactly as a rail card
    // would send them. Guessing here is what produced «تعذّر الإضافة».
    if (product.isVariable) {
      Haptics.light();
      await context.push<void>('/product/${product.id}', extra: product);
      return;
    }
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

    return switch (variant) {
      FamilyCardVariant.guest => _Invitation(paws: null, onTap: _signInThenAddPet),
      FamilyCardVariant.noPet => _Invitation(
          paws: summary!.paws.balance,
          onTap: () => context.push('/pets/new'),
        ),
      FamilyCardVariant.pending => _PetRow(
          pet: summary!.firstPet!,
          summary: summary,
          onTap: () => context.push('/family'),
          child: _PendingLine(order: summary.pendingOrders.first),
        ),
      FamilyCardVariant.due => _PetRow(
          pet: summary!.firstPet!,
          summary: summary,
          onTap: () => context.push('/family'),
          child: _DueLine(
            product: FamilyCard.dueProduct(widget.feed)!,
            busy: _adding,
            onOrder: () => _reorder(FamilyCard.dueProduct(widget.feed)!),
          ),
        ),
      FamilyCardVariant.mission => _PetRow(
          pet: summary!.firstPet!,
          summary: summary,
          onTap: () => context.push('/family'),
          child: _MissionLine(mission: summary.missions.nearest!),
        ),
      FamilyCardVariant.tier => _PetRow(
          pet: summary!.firstPet!,
          summary: summary,
          onTap: () => context.push('/family'),
          child: _StandingLine(summary: summary),
        ),
    };
  }
}

/// The shell every variant sits in: a warm card with the paw pattern in its
/// corner, so it is visibly the program's card and not another product tile.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final dark = context.isDark;
    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: dark
              ? [cs.surfaceContainer, cs.surfaceContainerLow]
              : [const Color(0xFFFFF9F2), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: dark ? cs.outlineVariant : const Color(0xFFF1E4D4)),
        boxShadow: [
          BoxShadow(
            color: ZbTokens.cardboard.withValues(alpha: dark ? 0 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const PositionedDirectional(
            end: -30,
            top: -20,
            width: 160,
            height: 120,
            child: PawPattern(color: ZbTokens.cardboard, opacity: 0.12, scale: 0.7),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );

    if (onTap == null) return card;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: card,
    );
  }
}

/// Guest, and member-with-no-pet: the same ask, one with a balance attached.
/// The mascots make the invitation — they are the family being joined.
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        balance == null ? l.familyGuestTitle : l.familyNoPetTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Gap.h12,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(balance == null ? l.familyGuestCta : l.familyAddPet),
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          // The two on the box, peeking in.
          ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            child: SizedBox(
              width: 104,
              height: 92,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                child: Image.asset(MascotPeek.asset, width: 220),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four member variants share a portrait, a name and the standing chips;
/// only the line under the name changes.
class _PetRow extends StatelessWidget {
  const _PetRow({required this.pet, required this.summary, required this.child, this.onTap});

  final Pet pet;
  final LoyaltySummary summary;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = summary.tier;
    return _Shell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpeciesAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 60),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (tier.name.isNotEmpty) ...[
                      Gap.w8,
                      TierChip(label: tier.name, c1: tier.c1, c2: tier.c2, compact: true),
                    ],
                  ],
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

/// "Your order is on its way" — and what lands when it does.
class _PendingLine extends StatelessWidget {
  const _PendingLine({required this.order});

  final PendingOrder order;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.familyPendingOrderTitle(order.number),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        Gap.h8,
        Row(
          children: [
            const PawCoin(size: 20),
            Gap.w6,
            Expanded(
              child: Text(
                l.familyPendingOrderPaws(Fmt.number(order.paws, locale: locale, decimals: 0)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(ZbTokens.rSm),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ZbImage(
                url: product.image,
                radius: BorderRadius.circular(ZbTokens.rSm),
                padding: const EdgeInsets.all(3),
              ),
            ),
            Gap.w8,
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onOrder,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
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

/// The nearest open mission, with the ring that says how close it is.
class _MissionLine extends StatelessWidget {
  const _MissionLine({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
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
                          valueColor: AlwaysStoppedAnimation(missionKindHue(context, mission.kind)),
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
          ),
        ),
        Gap.w10,
        MissionSticker(kind: mission.kind, size: 40),
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
    final l = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tier.next == null
              ? l.familyTierTop
              : l.familyTierNext(tier.ordersToNext, tier.next!.name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant),
        ),
        Gap.h8,
        PawsPill(paws: summary.paws.balance, compact: true),
      ],
    );
  }
}
