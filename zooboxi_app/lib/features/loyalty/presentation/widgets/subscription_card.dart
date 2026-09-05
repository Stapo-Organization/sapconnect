import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/qty_stepper.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_models.dart';
import 'loyalty_art.dart';

/// «التوصيلة بعد 12 يوم» / «التوصيلة اليوم» / «موعد التوصيلة فات».
String subscriptionWhen(L l, Subscription sub) {
  final days = sub.daysUntil;
  if (days == null) return '';
  if (days > 0) return l.subsNextIn(days);
  if (days == 0) return l.subsNextToday;
  return l.subsOverdue;
}

/// «كل شهر» / «كل أسبوعين» / «كل 45 يومًا».
String subscriptionEvery(L l, int days) => switch (days) {
      7 => l.subsEveryWeek,
      14 => l.subsEveryTwoWeeks,
      30 => l.subsEveryMonth,
      60 => l.subsEveryTwoMonths,
      _ => l.subsEvery(days),
    };

/// One soft subscription as a card: the product, the cadence, the next date,
/// and the two things a customer does with it — order it now, or skip it.
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    super.key,
    required this.sub,
    this.onOrderNow,
    this.onSkip,
    this.onEdit,
    this.busy = false,
    this.compact = false,
  });

  final Subscription sub;
  final VoidCallback? onOrderNow;
  final VoidCallback? onSkip;
  final VoidCallback? onEdit;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final due = sub.isDue;
    final hue = sub.isPaused ? cs.onSurfaceVariant : (due ? ZbTokens.logoCoral : ZbTokens.logoTeal);
    final pet = sub.pet;

    final title = [
      sub.product.name,
      if (sub.variationLabel.isNotEmpty) sub.variationLabel,
    ].join(' — ');

    final meta = <String>[
      l.subsQty(sub.qty),
      subscriptionEvery(l, sub.intervalDays),
      if (pet != null) l.supplyForPet(pet.name),
    ].join(' · ');

    return PressScale(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(ZbTokens.rXl),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rXl),
          border: Border.all(color: due ? hue.withValues(alpha: 0.45) : cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(ZbTokens.rMd),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: ZbImage(
                        url: sub.product.image,
                        radius: BorderRadius.circular(ZbTokens.rMd),
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                    PositionedDirectional(
                      end: -6,
                      bottom: -6,
                      child: FamilyMarkIcon(FamilyMark.repeat, size: 22, color: hue),
                    ),
                  ],
                ),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                      Row(
                        children: [
                          FamilyMarkIcon(sub.isPaused ? FamilyMark.moon : FamilyMark.clock, size: 14, color: hue),
                          Gap.w4,
                          Expanded(
                            child: Text(
                              sub.isPaused
                                  ? l.subsPaused
                                  : '${subscriptionWhen(l, sub)}${sub.nextAt != null ? ' · ${Fmt.dateShort(sub.nextAt!, locale)}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.labelMedium?.copyWith(color: hue, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              Gap.h8,
              Row(
                children: [
                  const PawCoin(size: 14),
                  Gap.w4,
                  Expanded(
                    child: Text(
                      [
                        l.subsDeliveries(sub.deliveries),
                        if (sub.nextGiftIn != null && sub.giftEvery > 0) l.subsNextGift(sub.nextGiftIn!),
                      ].join(' · '),
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (sub.isActive) ...[
              Gap.h12,
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onOrderNow,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: due ? hue : null),
                      child: busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.subsOrderNow),
                    ),
                  ),
                  if (onSkip != null) ...[
                    Gap.w8,
                    OutlinedButton(
                      onPressed: busy ? null : onSkip,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      child: Text(l.subsSkip),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The result of the editor sheet.
class SubscriptionEdit {
  const SubscriptionEdit({this.qty, this.intervalDays, this.nextAt, this.state, this.cancel = false});

  final int? qty;
  final int? intervalDays;
  final DateTime? nextAt;
  final String? state;
  final bool cancel;
}

/// Edit quantity, cadence, next date; pause/resume; cancel.
Future<SubscriptionEdit?> showSubscriptionEditor(BuildContext context, {required Subscription sub}) =>
    showZbSheet<SubscriptionEdit>(
      context,
      builder: (_) => _EditorSheet(sub: sub),
    );

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({required this.sub});

  final Subscription sub;

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late int _qty = widget.sub.qty;
  late int _interval = widget.sub.intervalDays;
  late DateTime? _next = widget.sub.nextAt;

  static const _intervals = [7, 14, 21, 30, 45, 60, 90];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (_next != null && _next!.isAfter(now)) ? _next! : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null && mounted) setState(() => _next = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final sub = widget.sub;
    final choices = {..._intervals, _interval}.toList()..sort();

    return BottomSheetScaffold(
      title: l.subsEditorTitle,
      subtitle: sub.product.name,
      footer: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(SubscriptionEdit(
                qty: _qty,
                intervalDays: _interval,
                nextAt: _next,
              )),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(l.subsSave),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.subsQtyLabel, style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h8,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: QtyStepper(value: _qty, min: 1, max: 10, onChanged: (v) => setState(() => _qty = v)),
            ),
            Gap.h20,
            Text(l.subsIntervalLabel, style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h8,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in choices)
                  ChoiceChip(
                    label: Text(subscriptionEvery(l, days)),
                    selected: _interval == days,
                    onSelected: (_) => setState(() => _interval = days),
                  ),
              ],
            ),
            Gap.h20,
            Text(l.subsNextLabel, style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            Gap.h8,
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const FamilyMarkIcon(FamilyMark.clock, size: 18),
              label: Text(_next == null ? '—' : Fmt.dateFull(_next!, locale)),
            ),
            Gap.h20,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      SubscriptionEdit(state: sub.isPaused ? 'active' : 'paused'),
                    ),
                    icon: FamilyMarkIcon(sub.isPaused ? FamilyMark.repeat : FamilyMark.moon, size: 18),
                    label: Text(sub.isPaused ? l.subsResume : l.subsPause),
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l.subsCancel),
                          content: Text(l.subsCancelConfirm),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.actionCancel)),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: FilledButton.styleFrom(backgroundColor: cs.error),
                              child: Text(l.subsCancel),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        Navigator.of(context).pop(const SubscriptionEdit(cancel: true));
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    child: Text(l.subsCancel),
                  ),
                ),
              ],
            ),
            Gap.h8,
          ],
        ),
      ),
    );
  }
}
