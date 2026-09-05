import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// The hue a supply line wears: teal while there is plenty, amber as it gets
/// close, coral when it is due, and the sale red once it has run out.
Color supplyHue(BuildContext context, SupplyItem item) {
  final zb = context.zb;
  return switch (item.status) {
    'soon' => ZbTokens.amber,
    'due' => ZbTokens.logoCoral,
    'overdue' => zb.sale,
    _ => ZbTokens.logoTeal,
  };
}

String supplyKindLabel(L l, String kind) => switch (kind) {
      'dry' => l.supplyKindDry,
      'wet' => l.supplyKindWet,
      'litter' => l.supplyKindLitter,
      'treat' => l.supplyKindTreat,
      _ => l.supplyKindOther,
    };

/// «يكفي 6 أيام» / «ينفد اليوم» / «نفد قبل 4 أيام».
String supplyDaysLabel(L l, SupplyItem item) {
  final days = item.daysLeft;
  if (days > 0) return l.supplyDaysLeft(days);
  if (days == 0) return l.supplyRunsOutToday;
  return l.supplyOverdue(-days);
}

/// The ring with the days inside — the gauge's face, reused by the card, the
/// home line and the pet card.
class SupplyRing extends StatelessWidget {
  const SupplyRing({super.key, required this.item, this.size = 56});

  final SupplyItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = supplyHue(context, item);
    final locale = Localizations.localeOf(context).languageCode;
    final days = item.daysLeft;
    final big = size >= 48;

    return ProgressRing(
      value: item.remaining,
      color: hue,
      size: size,
      stroke: big ? 5 : 3.5,
      child: days < 0
          ? FamilyMarkIcon(FamilyMark.bowl, size: size * 0.46)
          : Text(
              Fmt.number(days, locale: locale, decimals: 0),
              style: (big ? context.tt.titleMedium : context.tt.labelMedium)?.copyWith(
                fontWeight: FontWeight.w800,
                color: hue,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}

/// One line of the food gauge, as a card.
///
/// The ring says how much is left; the buttons are the three honest answers a
/// customer can give a forecast: order it, tell us it already ran out, or tell
/// us there is still enough. Nothing here nags — a wrong forecast is corrected
/// with one tap, and that tap is what teaches the model.
class SupplyGaugeCard extends StatelessWidget {
  const SupplyGaugeCard({
    super.key,
    required this.item,
    this.onOrder,
    this.onOut,
    this.onSnooze,
    this.onSubscribe,
    this.busy = false,
    this.compact = false,
    this.onTimePct = 20,
  });

  final SupplyItem item;
  final VoidCallback? onOrder;
  final VoidCallback? onOut;
  final VoidCallback? onSnooze;
  final VoidCallback? onSubscribe;
  final bool busy;

  /// The hub's shorter form: ring, name, one line, one button.
  final bool compact;
  final int onTimePct;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final hue = supplyHue(context, item);
    final locale = Localizations.localeOf(context).languageCode;
    final pet = item.pet;

    final meta = <String>[
      if (pet != null) l.supplyForPet(pet.name),
      supplyKindLabel(l, item.kind),
      if (item.packKg != null) l.supplyPack(Fmt.number(item.packKg!, locale: locale, decimals: 1)),
    ].join(' · ');

    final card = Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: item.isOk ? cs.outlineVariant : hue.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: context.isDark ? 0 : (item.isOk ? 0.06 : 0.14)),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SupplyRing(item: item, size: compact ? 52 : 60),
              Gap.w12,
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(ZbTokens.rSm),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: ZbImage(
                  url: item.product.image,
                  radius: BorderRadius.circular(ZbTokens.rSm),
                  padding: const EdgeInsets.all(3),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    Gap.h4,
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Gap.h4,
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Chip(text: supplyDaysLabel(l, item), color: hue, filled: !item.isOk),
                        if (item.onTime && !compact) _Chip(text: l.supplyOnTimeBadge(onTimePct), color: ZbTokens.amber, coin: true),
                        if (item.hasSubscription) _Chip(text: l.supplySubscribed, color: ZbTokens.logoTeal, mark: FamilyMark.repeat),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            Gap.h8,
            Text(
              [
                l.supplyCycle(Fmt.number(item.cycleDays * item.qtyLast, locale: locale, decimals: 0)),
                switch (item.confidence) {
                  'high' => l.supplyConfidenceHigh,
                  'medium' => l.supplyConfidenceMedium,
                  _ => l.supplyConfidenceLow,
                },
              ].join(' · '),
              style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onOrder,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: item.isOk ? null : hue,
                  ),
                  child: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(l.supplyOrderNow, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (item.onTime) ...[
                              Gap.w6,
                              const PawCoin(size: 16),
                            ],
                          ],
                        ),
                ),
              ),
              if (!compact) ...[
                Gap.w8,
                _IconAction(
                  mark: FamilyMark.bowl,
                  label: l.supplyOut,
                  onTap: busy ? null : onOut,
                  color: ZbTokens.logoCoral,
                ),
                Gap.w6,
                _IconAction(
                  mark: FamilyMark.moon,
                  label: l.supplySnooze,
                  onTap: busy ? null : onSnooze,
                  color: ZbTokens.amber,
                ),
                if (!item.hasSubscription && onSubscribe != null) ...[
                  Gap.w6,
                  _IconAction(
                    mark: FamilyMark.repeat,
                    label: l.supplySubscribe,
                    onTap: busy ? null : onSubscribe,
                    color: ZbTokens.logoTeal,
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );

    return card;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, this.filled = false, this.coin = false, this.mark});

  final String text;
  final Color color;
  final bool filled;
  final bool coin;
  final FamilyMark? mark;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coin) ...[const PawCoin(size: 12), Gap.w4],
          if (mark != null) ...[FamilyMarkIcon(mark!, size: 12, color: filled ? Colors.white : color), Gap.w4],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: filled ? Colors.white : (dark ? context.cs.onSurface : Color.lerp(color, ZbTokens.ink, 0.35)),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A square secondary action: the mark above a one-word label.
class _IconAction extends StatelessWidget {
  const _IconAction({required this.mark, required this.label, required this.color, this.onTap});

  final FamilyMark mark;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: Container(
        width: 52,
        height: 42,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FamilyMarkIcon(mark, size: 18, color: color),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

/// «يكفي 6 أيام» as a chip for the pet card — the gauge at a glance.
class SupplyChip extends StatelessWidget {
  const SupplyChip({super.key, required this.item});

  final SupplyItem item;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hue = supplyHue(context, item);
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 3, 9, 3),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SupplyRing(item: item, size: 18),
          Gap.w6,
          Text(
            supplyDaysLabel(l, item),
            style: context.tt.labelSmall?.copyWith(
              color: dark ? context.cs.onSurface : Color.lerp(hue, ZbTokens.ink, 0.35),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
