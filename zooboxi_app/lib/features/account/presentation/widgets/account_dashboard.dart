import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/live_order_bar.dart';
import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/location/location_controller.dart';
import '../../../../core/utils/error_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../catalog/data/product_models.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../orders/data/live_tracking.dart';
import '../../../pets/data/household.dart' show castForSpecies;
import '../../../pets/data/pet_models.dart';
import '../../../pets/presentation/widgets/pet_card.dart' show speciesLabel;

/// «حسابي» as the owner picked it on the canvas (direction D, 2026-09-24):
/// the membership card the characters sit on, the parcel on its way in
/// express orange, a card per pet, and everything else as tiles that carry
/// their own numbers. The settings live one tap away behind the gear.

// ─────────────────────────── the membership card ───────────────────────────

/// The member's card: name, standing, paws and the next rung — with the cat
/// lying along its top edge and the dog sitting on it, as on a shelf.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.name,
    this.tier,
    this.paws = 0,
    this.pending = 0,
    this.onTap,
    this.onRewards,
  });

  final String name;
  final TierInfo? tier;
  final int paws;
  final int pending;
  final VoidCallback? onTap;
  final VoidCallback? onRewards;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dark = context.isDark;
    final standing = tier;
    final next = standing?.next;
    final left = standing?.ordersToNext ?? 0;
    final fresh = paws <= 0 && pending <= 0;

    final String? progressLine = switch (standing) {
      null => null,
      _ when next == null || next.name.isEmpty => l.accountTopTier,
      _ when left <= 0 => null,
      _ => l.accountTierProgress(left, next.name),
    };

    const white = Colors.white;
    return Padding(
      // Room above the card for the characters sitting on it, clear of the
      // bell and the gear.
      padding: const EdgeInsets.only(top: 92),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PressScale(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ZbTokens.rXl + 2),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZbTokens.rXl + 2),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: dark
                      ? const [ZbTokens.tealNight, ZbTokens.tealContainerDark]
                      : const [ZbTokens.tealDeep, ZbTokens.tealDark, ZbTokens.teal],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ZbTokens.tealDeep.withValues(alpha: dark ? 0.2 : 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DotsPainter(white.withValues(alpha: 0.12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.familyTitle,
                                style: context.tt.labelMedium?.copyWith(
                                  color: white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Gap.h4,
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.headlineSmall?.copyWith(
                                  color: white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (standing != null && standing.name.isNotEmpty) ...[
                          Gap.w8,
                          _TierChip(label: standing.name),
                        ],
                      ],
                    ),
                    Gap.h16,
                    if (fresh)
                      Row(
                        children: [
                          const Icon(Icons.pets_rounded, size: 24, color: ZbTokens.sparkAmber),
                          Gap.w8,
                          Expanded(
                            child: Text(
                              l.accountFirstPaws,
                              style: context.tt.titleMedium?.copyWith(
                                color: white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                Fmt.number(paws, locale: locale, decimals: 0),
                                style: context.tt.displaySmall?.copyWith(
                                  color: white,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              Gap.w6,
                              Text(
                                l.accountStatPaws,
                                style: context.tt.titleSmall?.copyWith(
                                  color: white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (pending > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                              ),
                              child: Text(
                                l.accountPawsPending(pending),
                                style: context.tt.labelSmall?.copyWith(
                                  color: white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (standing != null && next != null) ...[
                      Gap.h12,
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        child: LinearProgressIndicator(
                          value: standing.progress.clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: white.withValues(alpha: 0.22),
                          color: ZbTokens.sparkAmber,
                        ),
                      ),
                    ],
                    Gap.h8,
                    Row(
                      children: [
                        if (progressLine != null)
                          Expanded(
                            child: Text(
                              progressLine,
                              style: context.tt.bodySmall?.copyWith(
                                color: white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (onRewards != null)
                          InkWell(
                            onTap: onRewards,
                            borderRadius: BorderRadius.circular(ZbTokens.rSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.accountRewards,
                                    style: context.tt.labelMedium?.copyWith(
                                      color: white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Icon(
                                    context.isRtl
                                        ? Icons.chevron_left_rounded
                                        : Icons.chevron_right_rounded,
                                    size: 18,
                                    color: white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The cat lies along the card's top edge at the reading start, the
          // dog sits at the far end — the card is their shelf.
          PositionedDirectional(
            top: -52,
            start: 22,
            child: IgnorePointer(
              child: ZbSticker.cast(ZbCast.cat, ZbPose.lie, height: 58, entrance: false),
            ),
          ),
          PositionedDirectional(
            top: -82,
            end: 24,
            child: IgnorePointer(
              child: ZbSticker.cast(ZbCast.dog, ZbPose.sitUp, height: 84, entrance: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 15, color: ZbTokens.sparkAmber),
          Gap.w4,
          Text(
            label,
            style: context.tt.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 18.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

// ─────────────────────────── the parcel on its way ───────────────────────────

/// The order that is moving right now, in express orange, with the clock it
/// arrives by when the courier has one — the thing on this screen that will
/// not be true tomorrow.
class LiveOrderTile extends StatelessWidget {
  const LiveOrderTile({super.key, required this.active, required this.onTap});

  final ActiveOrder active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final eta = active.tracking?.etaMinutes;
    final progress = liveOrderProgress(active).clamp(0.0, 1.0);
    final filled = (progress * 4).ceil().clamp(1, 4);
    final thumbs = [
      for (final item in active.order.itemsPreview)
        if (item.image != null && item.image!.isNotEmpty) item.image!,
    ].take(3).toList();
    const white = Colors.white;

    return PressScale(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [ZbTokens.expressFg, ZbTokens.logoCoral],
          ),
          boxShadow: [
            BoxShadow(
              color: ZbTokens.expressFg.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_rounded, size: 17, color: white),
                          Gap.w6,
                          Flexible(
                            child: Text(
                              l.accountActiveOrder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.labelLarge?.copyWith(color: white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Gap.h8,
                      if (eta != null)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 6,
                          children: [
                            Text(
                              l.accountArrives,
                              style: context.tt.titleSmall?.copyWith(color: white, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              Fmt.clock(DateTime.now().add(Duration(minutes: eta)), locale),
                              style: context.tt.headlineMedium?.copyWith(
                                color: white,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          liveOrderHeadline(context, active),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleLarge?.copyWith(color: white, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
                if (thumbs.isNotEmpty) ...[
                  Gap.w8,
                  _Stack(images: thumbs, size: 44, ring: ZbTokens.expressFg),
                ],
              ],
            ),
            Gap.h12,
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) Gap.w4,
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < filled ? white : white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (i, step) in [
                  l.accountStepReceived,
                  l.accountStepPacked,
                  l.accountStepOnWay,
                  l.accountStepDelivered,
                ].indexed)
                  Expanded(
                    child: Text(
                      step,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: switch (i) {
                        0 => TextAlign.start,
                        3 => TextAlign.end,
                        _ => TextAlign.center,
                      },
                      style: context.tt.labelSmall?.copyWith(
                        color: white.withValues(alpha: i < filled ? 0.95 : 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A short, overlapping stack of product pictures on white tiles.
class _Stack extends StatelessWidget {
  const _Stack({required this.images, this.size = 32, this.ring});

  final List<String> images;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final border = ring ?? context.cs.surface;
    return SizedBox(
      height: size,
      width: size + (images.length - 1) * (size - 10),
      child: Stack(
        children: [
          for (var i = 0; i < images.length; i++)
            PositionedDirectional(
              start: i * (size - 10),
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.3),
                  border: Border.all(color: border, width: 2),
                ),
                child: ZbImage(url: images[i], radius: BorderRadius.circular(size * 0.22)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────── the pets ───────────────────────────

/// The soonest food line for one pet, if the server has one.
SupplyItem? foodLineFor(LoyaltySummary? summary, int petId) {
  if (summary == null) return null;
  final lines = [
    for (final item in summary.supply.items)
      if (item.pet?.id == petId && (item.kind == 'dry' || item.kind == 'wet')) item,
  ]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return lines.isEmpty ? null : lines.first;
}

/// One card per pet: who they are, how long their food lasts, and the one
/// thing to do about it — side by side, swiped like a shelf.
class PetCardsRow extends ConsumerWidget {
  const PetCardsRow({super.key, required this.pets, required this.summary});

  final List<Pet> pets;
  final LoyaltySummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 214 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.35),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pets.length + 1,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (context, i) => i == pets.length
            ? const _AddPetTile()
            : _PetCard(pet: pets[i], food: foodLineFor(summary, pets[i].id)),
      ),
    );
  }
}

class _PetCard extends ConsumerStatefulWidget {
  const _PetCard({required this.pet, this.food});

  final Pet pet;
  final SupplyItem? food;

  @override
  ConsumerState<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends ConsumerState<_PetCard> {
  bool _adding = false;

  Future<void> _order(SupplyItem line) async {
    if (_adding) return;
    // A size to choose first: the product page asks, not a blind add.
    if (line.product.isVariable && line.variationId <= 0) {
      unawaited(context.push('/product/${line.product.id}', extra: line.product));
      return;
    }
    final l = L.of(context);
    setState(() => _adding = true);
    Haptics.light();
    try {
      final result = await ref.read(cartControllerProvider.notifier).add(
            productId: line.product.id,
            variationId: line.variationId > 0 ? line.variationId : null,
            quantity: line.qtyLast < 1 ? 1 : line.qtyLast,
          );
      if (!mounted) return;
      if (result.added) {
        await Haptics.success();
        if (mounted) AppToast.success(context, l.petShelfAdded(1));
      }
    } catch (e) {
      if (mounted) AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    final pet = widget.pet;
    final food = widget.food;
    final cat = pet.species == PetSpecies.cat;
    final tone = dark
        ? (cat ? ZbTokens.coralContainerDark : ZbTokens.amberContainerDark)
        : (cat ? ZbTokens.coralTintSoft : ZbTokens.amberTintSoft);
    final days = food == null ? null : (food.daysLeft < 0 ? 0 : food.daysLeft);
    final low = days != null && days <= 3;
    final express = ref.watch(currentLocationProvider).deliveryType == 'express';

    final (String chip, IconData chipIcon) = switch (pet.birthdayInDays) {
      final d? when pet.isBirthdaySoon => (l.petBirthdaySoon(d), Icons.cake_outlined),
      _ => (
          [speciesLabel(l, pet.species), if ((pet.ageLabel ?? '').isNotEmpty) pet.ageLabel!].join(' · '),
          Icons.pets_rounded,
        ),
    };

    return SizedBox(
      width: 264,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ZbSticker.cast(
                      castForSpecies(pet.species) ?? ZbCast.cat,
                      ZbPose.sitUp,
                      height: 70,
                      entrance: false,
                    ),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Gap.h4,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chipIcon, size: 13, color: cat ? ZbTokens.coral : ZbTokens.cardboard),
                            Gap.w4,
                            Flexible(
                              child: Text(
                                chip,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.h12,
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dark ? ZbTokens.graphiteHigh : ZbTokens.canvasLight,
                  borderRadius: BorderRadius.circular(ZbTokens.rLg),
                ),
                child: Row(
                  children: [
                    if (food?.product.image case final image?) ...[
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ZbImage(url: image, photo: true, radius: BorderRadius.circular(ZbTokens.rXs)),
                      ),
                      Gap.w10,
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (days) {
                              null => l.accountPetNoFood,
                              0 => l.petShelfFoodOut(pet.name),
                              final d => l.petShelfFoodDays(pet.name, d),
                            },
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: low ? cs.error : cs.onSurface,
                            ),
                          ),
                          if (food != null) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ZbTokens.rPill),
                              child: LinearProgressIndicator(
                                value: food.cycleDays <= 0 ? 0 : (days! / food.cycleDays).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
                                color: low ? ZbTokens.coral : ZbTokens.teal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap.h12,
            if (food != null)
              FilledButton(
                onPressed: _adding ? null : () => _order(food),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: low ? ZbTokens.expressFg : (dark ? ZbTokens.tealContainerDark : ZbTokens.tealTint),
                  foregroundColor: low ? Colors.white : (dark ? ZbTokens.tealOnDark : ZbTokens.tealDeep),
                ),
                child: _adding
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : Text(express ? l.accountPetOrderExpress : l.accountPetOrder),
              )
            else
              OutlinedButton(
                onPressed: () => context.push('/pets/${pet.id}'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(l.accountPetProfile(pet.name), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPetTile extends StatelessWidget {
  const _AddPetTile();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return SizedBox(
      width: 120,
      child: PressScale(
        onTap: () => context.push('/pets/new'),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        child: CustomPaint(
          painter: _DashedBorder(color: cs.outline.withValues(alpha: 0.6), radius: ZbTokens.rXl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, color: cs.primary),
                ),
                Gap.h8,
                Text(
                  l.accountAddPet,
                  textAlign: TextAlign.center,
                  style: context.tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// «مين معك في البيت؟» where the pets would be, for a member with none yet.
class HouseholdInviteCard extends StatelessWidget {
  const HouseholdInviteCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final ink = dark ? ZbTokens.inkDark : ZbTokens.inkWarm;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 0),
        decoration: BoxDecoration(
          color: dark ? ZbTokens.coralContainerDark : ZbTokens.coralTintSoft,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.storyCoralLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.onbPetsTitle, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(height: 6),
                    Text(
                      l.accountHouseholdBody,
                      style: context.tt.bodySmall?.copyWith(color: ink.withValues(alpha: 0.8), height: 1.5),
                    ),
                    Gap.h12,
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(backgroundColor: ZbTokens.expressFg, minimumSize: const Size(0, 42)),
                      child: Text(l.accountHouseholdCta),
                    ),
                  ],
                ),
              ),
            ),
            Gap.w8,
            ZbSticker.cast(ZbCast.cat, ZbPose.present, height: 130, entrance: false),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── the tiles ───────────────────────────

/// A tile that carries its own number and a glimpse of what is behind it.
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.color,
    required this.title,
    this.count,
    this.hint,
    this.images = const [],
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String title;
  final int? count;
  final String? hint;
  final List<String> images;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    return PressScale(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
          border: Border.all(color: context.isDark ? ZbTokens.lineDark : ZbTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(ZbTokens.rSm)),
                  child: Icon(icon, size: 19, color: color),
                ),
                const Spacer(),
                if (count case final n? when n > 0)
                  Text(
                    Fmt.number(n, locale: locale, decimals: 0),
                    style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (images.isNotEmpty)
              _Stack(images: images.take(3).toList(), size: 30)
            else if (hint != null)
              Text(
                hint!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two tiles side by side, as tall as the taller of them.
class TilePair extends StatelessWidget {
  const TilePair({super.key, required this.start, this.end});

  final Widget start;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: start),
          Gap.w10,
          Expanded(child: end ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// «مشترياتك المعتادة» — the last few things bought, and one button that puts
/// them back in the basket.
class UsualTile extends ConsumerStatefulWidget {
  const UsualTile({super.key, required this.products, required this.onOpen});

  final List<ProductCard> products;
  final VoidCallback onOpen;

  @override
  ConsumerState<UsualTile> createState() => _UsualTileState();
}

class _UsualTileState extends ConsumerState<UsualTile> {
  bool _adding = false;

  List<ProductCard> get _shown => widget.products.where((p) => p.image != null).take(3).toList();

  Future<void> _addAll() async {
    if (_adding) return;
    final l = L.of(context);
    setState(() => _adding = true);
    Haptics.light();
    var added = 0;
    try {
      for (final product in _shown) {
        // A product with sizes waits for its page; the rest go straight in.
        if (product.isVariable) continue;
        final result = await ref.read(cartControllerProvider.notifier).add(productId: product.id);
        if (result.added) added++;
      }
      if (!mounted) return;
      if (added > 0) {
        await Haptics.success();
        if (mounted) AppToast.success(context, l.petShelfAdded(added));
      } else {
        AppToast.info(context, l.petShelfPickPack);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
        border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.accountUsualTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(onPressed: widget.onOpen, child: Text(l.accountUsualAll)),
            ],
          ),
          Gap.h4,
          Row(
            children: [
              for (final product in _shown) ...[
                PressScale(
                  onTap: () => context.push('/product/${product.id}', extra: product),
                  borderRadius: BorderRadius.circular(ZbTokens.rMd),
                  child: Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: dark ? ZbTokens.photoMatDark : ZbTokens.canvasLight,
                      borderRadius: BorderRadius.circular(ZbTokens.rMd),
                    ),
                    child: ZbImage(url: product.image, radius: BorderRadius.circular(ZbTokens.rXs)),
                  ),
                ),
                Gap.w8,
              ],
              const Spacer(),
              FilledButton(
                onPressed: _adding ? null : _addAll,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: _adding
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.onPrimary),
                      )
                    : Text(l.accountAddAll, maxLines: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A wide tile for the member who has not ordered yet.
class FirstOrderTile extends StatelessWidget {
  const FirstOrderTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
        border: Border.all(color: context.isDark ? ZbTokens.lineDark : ZbTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(ZbTokens.rMd)),
                child: Icon(Icons.shopping_bag_outlined, color: cs.primary),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.accountFirstOrderTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Gap.h4,
                    Text(
                      l.accountFirstOrderBody,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h12,
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(l.accountStartShopping),
          ),
        ],
      ),
    );
  }
}

/// «ادعُ صديقاً» — the dog presents it; the reward is the store's own number.
class InviteTile extends StatelessWidget {
  const InviteTile({super.key, required this.rewardPaws, required this.onTap});

  final int rewardPaws;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    final ink = dark ? ZbTokens.inkDark : ZbTokens.inkWarm;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 0),
        decoration: BoxDecoration(
          color: dark ? ZbTokens.amberContainerDark : ZbTokens.amberTintSoft,
          borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
          border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.storyAmberLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.accountInviteTitle, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: ink)),
                    Gap.h4,
                    Text(
                      l.accountInviteBody(rewardPaws),
                      style: context.tt.bodySmall?.copyWith(color: ink.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: dark ? ZbTokens.amberOnDark : ZbTokens.inkWarm,
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                      ),
                      child: Text(
                        l.accountInviteCta,
                        style: context.tt.labelMedium?.copyWith(
                          color: dark ? ZbTokens.graphite : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ZbSticker.cast(ZbCast.dog, ZbPose.present, height: 104, entrance: false),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── the guest ───────────────────────────

/// The same card, for someone the shop has not met: an invitation with the
/// two characters waving over it, and what signing in actually gives.
class GuestInviteCard extends StatelessWidget {
  const GuestInviteCard({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dark = context.isDark;
    const white = Colors.white;
    return Padding(
      padding: const EdgeInsets.only(top: 96),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZbTokens.rXl + 4),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: dark
                    ? const [ZbTokens.tealNight, ZbTokens.tealContainerDark]
                    : const [ZbTokens.tealDeep, ZbTokens.tealDark, ZbTokens.teal],
              ),
            ),
            child: CustomPaint(
              painter: _DotsPainter(white.withValues(alpha: 0.12)),
              child: Column(
                children: [
                  Text(
                    l.accountGuestTitle,
                    textAlign: TextAlign.center,
                    style: context.tt.headlineSmall?.copyWith(color: white, fontWeight: FontWeight.w900),
                  ),
                  Gap.h8,
                  Text(
                    l.accountGuestBody,
                    textAlign: TextAlign.center,
                    style: context.tt.bodyMedium?.copyWith(color: white.withValues(alpha: 0.92), height: 1.55),
                  ),
                  Gap.h16,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: white,
                        foregroundColor: ZbTokens.tealDeep,
                        minimumSize: const Size(0, 50),
                        textStyle: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      child: Text(l.accountGuestCta),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.accountGuestNote,
                    style: context.tt.labelSmall?.copyWith(color: white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: -84,
            start: 44,
            child: IgnorePointer(child: ZbSticker.cast(ZbCast.cat, ZbPose.wave, height: 96, entrance: false)),
          ),
          PositionedDirectional(
            top: -90,
            end: 44,
            child: IgnorePointer(child: ZbSticker.cast(ZbCast.dog, ZbPose.wave, height: 96, entrance: false)),
          ),
        ],
      ),
    );
  }
}

/// What signing in gives, said as three plain lines.
class GuestPerks extends StatelessWidget {
  const GuestPerks({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    Widget perk(IconData icon, Color color, Color tint, String title, String body, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: dark ? ZbTokens.lineDark : ZbTokens.line)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(ZbTokens.rSm)),
                child: Icon(icon, size: 20, color: color),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(body, style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl - 2),
        border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.line),
      ),
      child: Column(
        children: [
          perk(Icons.local_shipping_outlined, ZbTokens.expressFg, dark ? ZbTokens.expressBgDark : ZbTokens.expressBg,
              l.accountPerkTrack, l.accountPerkTrackBody),
          perk(Icons.replay_rounded, ZbTokens.success, dark ? ZbTokens.greenContainerDark : ZbTokens.greenTint,
              l.accountPerkReorder, l.accountPerkReorderBody),
          perk(Icons.pets_rounded, ZbTokens.coral, dark ? ZbTokens.coralContainerDark : ZbTokens.coralTint,
              l.accountPerkPet, l.accountPerkPetBody,
              last: true),
        ],
      ),
    );
  }
}
