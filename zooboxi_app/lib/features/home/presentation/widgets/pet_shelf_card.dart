import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/utils/error_text.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/data/cart_controller.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../pets/data/household.dart';
import 'replenish_tile.dart';

/// «رفّ لولو» — the pet's own shelf at the top of the home.
///
/// The food gauge used to live inside «عائلة زوبوكسي», and the home carried at
/// most one due line. Here the pet leads: how many days its food has left, its
/// usual food, litter and treat side by side, and one button that puts all of
/// them in the basket. With a single line to show it stays the replenish tile.
class PetShelfCard extends ConsumerStatefulWidget {
  const PetShelfCard({super.key, this.express = true});

  /// Whether the two-hour promise may be made here.
  final bool express;

  @override
  ConsumerState<PetShelfCard> createState() => _PetShelfCardState();
}

/// The pet the shelf is about and its usual lines, food first.
@visibleForTesting
({PetRef pet, List<SupplyItem> lines})? petShelfOf(LoyaltySummary? summary) {
  if (summary == null) return null;
  final byPet = <int, List<SupplyItem>>{};
  final pets = <int, PetRef>{};
  for (final item in summary.supply.items) {
    final pet = item.pet;
    if (pet == null) continue;
    pets[pet.id] = pet;
    (byPet[pet.id] ??= []).add(item);
  }
  if (byPet.isEmpty) return null;

  int rank(String kind) => switch (kind) {
        'dry' || 'wet' => 0,
        'litter' => 1,
        'treat' => 2,
        _ => 3,
      };
  int soonest(SupplyItem a, SupplyItem b) =>
      (a.runsOutAt ?? DateTime(9999)).compareTo(b.runsOutAt ?? DateTime(9999));

  // The pet whose food runs out first is the one worth a card today.
  final ordered = byPet.entries.toList()
    ..sort((a, b) {
      final fa = a.value.where((i) => rank(i.kind) == 0).toList()..sort(soonest);
      final fb = b.value.where((i) => rank(i.kind) == 0).toList()..sort(soonest);
      if (fa.isEmpty != fb.isEmpty) return fa.isEmpty ? 1 : -1;
      if (fa.isEmpty) return 0;
      return soonest(fa.first, fb.first);
    });
  final chosen = ordered.first;

  // One line per kind — the soonest of each — food, then litter, then treat.
  final seen = <int>{};
  final lines = [...chosen.value]..sort((a, b) {
      final byKind = rank(a.kind).compareTo(rank(b.kind));
      return byKind != 0 ? byKind : soonest(a, b);
    });
  final picked = <SupplyItem>[
    for (final line in lines)
      if (rank(line.kind) < 3 && seen.add(rank(line.kind))) line,
  ];
  if (picked.isEmpty) return null;
  return (pet: pets[chosen.key]!, lines: picked);
}

class _PetShelfCardState extends ConsumerState<PetShelfCard> {
  bool _adding = false;

  Future<void> _orderAll(List<SupplyItem> lines) async {
    if (_adding) return;
    final l = L.of(context);
    setState(() => _adding = true);
    Haptics.light();
    var added = 0;
    var needsChoice = false;
    try {
      for (final line in lines) {
        ref.read(eventsBufferProvider).track(
              ZbEvent(
                type: ZbEvents.supplyAction,
                zone: 'home_pet_shelf',
                payload: {'product_id': line.product.id, 'action': 'order'},
              ),
            );
        // A variable product with no pack on record cannot be added blind.
        if (line.product.isVariable && line.variationId <= 0) {
          needsChoice = true;
          continue;
        }
        final result = await ref.read(cartControllerProvider.notifier).add(
              productId: line.product.id,
              variationId: line.variationId > 0 ? line.variationId : null,
              quantity: line.qtyLast < 1 ? 1 : line.qtyLast,
            );
        if (result.added) added++;
      }
      if (!mounted) return;
      if (added > 0) {
        await Haptics.success();
        if (!mounted) return;
        AppToast.success(context, l.petShelfAdded(added));
      } else if (needsChoice) {
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
    final summary = ref.watch(loyaltySummaryProvider).value;
    final shelf = petShelfOf(summary);
    if (shelf == null || shelf.lines.length < 2) {
      return ReplenishTile(express: widget.express);
    }

    final l = L.of(context);
    final cs = context.cs;
    final dark = context.isDark;
    final pet = shelf.pet;
    final food = shelf.lines.firstWhere(
      (line) => line.kind == 'dry' || line.kind == 'wet',
      orElse: () => shelf.lines.first,
    );
    final days = food.daysLeft < 0 ? 0 : food.daysLeft;
    final low = days <= 3;
    final fill = food.cycleDays <= 0 ? 0.0 : (days / food.cycleDays).clamp(0.0, 1.0);
    final cast = castForSpecies(pet.species) ?? ZbCast.cat;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? const [ZbTokens.coralContainerDark, ZbTokens.graphiteRaised]
                : const [ZbTokens.cream, ZbTokens.coralTintSoft],
          ),
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: dark ? ZbTokens.lineDark : ZbTokens.storyCoralLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: dark ? ZbTokens.graphiteHigh : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.bottomCenter,
                  child: ZbSticker.cast(cast, ZbPose.peek, height: 40, entrance: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.petShelfTitle(pet.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        days == 0 ? l.petShelfFoodOut(pet.name) : l.petShelfFoodDays(pet.name, days),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(
                          color: low ? cs.error : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ZbTokens.rPill),
                        child: LinearProgressIndicator(
                          value: fill,
                          minHeight: 7,
                          backgroundColor: (low ? cs.error : ZbTokens.coral).withValues(alpha: 0.18),
                          color: low ? cs.error : ZbTokens.coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < shelf.lines.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _LineTile(line: shelf.lines[i])),
                ],
                // Keep three columns so two lines read as a shelf, not a stretch.
                for (var i = shelf.lines.length; i < 3; i++) ...[
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _adding ? null : () => _orderAll(shelf.lines),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: widget.express ? ZbTokens.expressFg : null,
              ),
              child: _adding
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.onPrimary),
                    )
                  : Text(widget.express ? l.petShelfOrderAllExpress : l.petShelfOrderAll),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final SupplyItem line;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final label = switch (line.kind) {
      'dry' || 'wet' => l.petShelfFood,
      'litter' => l.petShelfLitter,
      _ => l.petShelfTreat,
    };
    return PressScale(
      onTap: () => context.push('/product/${line.product.id}', extra: line.product),
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.isDark ? ZbTokens.graphiteHigh : Colors.white,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 58,
              child: ZbImage(
                url: line.product.image,
                photo: true,
                radius: BorderRadius.circular(ZbTokens.rSm),
                padding: const EdgeInsets.all(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
