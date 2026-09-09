import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../loyalty/presentation/supply_actions.dart';

/// «يخلص طعام أوريو خلال ٤ أيام» — the one tile no grocery app can draw.
///
/// The store knows the animal, its weight and its feeding plan, so it knows
/// the bowl is running low before the owner does. Until now that lived inside
/// the family card, one of six things it might say. On a two-hour shelf it is
/// the most useful sentence on the page, so it gets a tile of its own — and
/// the tile is quiet when there is nothing to say, which is most days.
///
/// The ring is the same gauge the family hub draws; the button is the whole
/// point: the same product, the same pack, the same quantity, one tap, and it
/// is at the door in two hours. That turns a reminder into a solution.
class ReplenishTile extends ConsumerStatefulWidget {
  const ReplenishTile({super.key, this.express = true});

  /// Whether the two-hour promise may be made here.
  final bool express;

  @override
  ConsumerState<ReplenishTile> createState() => _ReplenishTileState();
}

class _ReplenishTileState extends ConsumerState<ReplenishTile> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(loyaltySummaryProvider).value;
    final item = summary?.supplyDue;
    if (item == null) return const SizedBox.shrink();

    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final out = item.daysLeft <= 0;
    final tone = out ? cs.error : zb.warning;
    final pet = item.pet?.name;

    final title = out
        ? (pet == null ? l.replenishOutNoPet : l.replenishOut(pet))
        : '${pet == null ? l.replenishTitleNoPet : l.replenishTitle(pet)} ${l.replenishDays(item.daysLeft)}';

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            context.push('/family/supply');
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [tone.withValues(alpha: 0.10), tone.withValues(alpha: 0.02)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _GaugeAvatar(item: item, tone: tone),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Gap.h8,
                      FilledButton.tonal(
                        onPressed: _adding
                            ? null
                            : () async {
                                setState(() => _adding = true);
                                await orderSupplyItem(context, ref, item, zone: 'home_replenish');
                                if (mounted) setState(() => _adding = false);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: tone.withValues(alpha: context.isDark ? 0.28 : 0.16),
                          foregroundColor: context.isDark ? cs.onSurface : tone,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_adding)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(widget.express ? Icons.bolt_rounded : Icons.replay_rounded, size: 16),
                            Gap.w6,
                            Text(widget.express ? l.replenishCta : l.replenishCtaPlain),
                            if (widget.express) ...[
                              Gap.w6,
                              Text(
                                '· ${l.replenishArrives}',
                                style: context.tt.labelSmall?.copyWith(
                                  color: (context.isDark ? cs.onSurface : tone).withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The product's photo wearing how much of the last pack is left.
class _GaugeAvatar extends StatelessWidget {
  const _GaugeAvatar({required this.item, required this.tone});

  final SupplyItem item;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: item.remaining.clamp(0.0, 1.0),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              backgroundColor: tone.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: ZbImage(url: item.product.image, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}
