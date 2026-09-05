import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/product_models.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../data/care_models.dart';
import '../../data/pet_models.dart';

/// The painted mark a reminder kind wears.
FamilyMark careMarkOf(String kind) => switch (kind) {
      'vaccine' => FamilyMark.shield,
      'deworm' => FamilyMark.pill,
      'flea_tick' => FamilyMark.bug,
      'grooming' => FamilyMark.scissors,
      _ => FamilyMark.steth,
    };

/// The hue a reminder's state wears: teal while fine, amber when close,
/// coral on the day, the sale red once it has slipped.
Color careHue(BuildContext context, CareReminder r) => switch (r.state) {
      'soon' => ZbTokens.amber,
      'due' => ZbTokens.logoCoral,
      'overdue' => context.zb.sale,
      'unset' || 'off' => context.cs.onSurfaceVariant,
      _ => ZbTokens.logoTeal,
    };

/// «بعد 12 يومًا» / «اليوم» / «تأخر 3 أيام» / «غير مضبوط».
String careStateLabel(L l, CareReminder r) {
  switch (r.state) {
    case 'unset':
      return l.careStateUnset;
    case 'off':
      return l.careStateOff;
    case 'due':
      return l.careStateDue;
    case 'overdue':
      return l.careStateOverdue(-(r.days ?? 0));
    default:
      return l.careStateIn(r.days ?? 0);
  }
}

/// «كل 3 أشهر» — the interval, in words when it is a round one.
String careIntervalLabel(L l, int days) => switch (days) {
      7 => l.careEveryWeek,
      14 => l.careEveryTwoWeeks,
      30 => l.careEveryMonth,
      60 => l.careEveryTwoMonths,
      90 => l.careEveryQuarter,
      180 => l.careEveryHalfYear,
      365 => l.careEveryYear,
      _ => l.careIntervalDays(days),
    };

String careStageLabel(L l, String stage) => switch (stage) {
      'kitten' || 'puppy' => l.careFeedStageKitten,
      'junior' => l.careFeedStageJunior,
      'senior' => l.careFeedStageSenior,
      _ => l.careFeedStageAdult,
    };

/// A section title with an optional trailing action, the profile's rhythm.
class CareHeader extends StatelessWidget {
  const CareHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  Gap.h4,
                  Text(subtitle!, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      );
}

/// The white card every section sits in.
class CareCard extends StatelessWidget {
  const CareCard({super.key, required this.child, this.accent, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hue = accent ?? cs.primary;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: context.isDark ? 0 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// A row of small mutually exclusive choices: the activity and body pickers.
class CareSegments extends StatelessWidget {
  const CareSegments({super.key, required this.value, required this.options, required this.onChanged, this.busy = false});

  final String value;

  /// key → label.
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          for (final (key, label) in options)
            Expanded(
              child: PressScale(
                onTap: busy || key == value ? null : () => onChanged(key),
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: key == value ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(ZbTokens.rPill),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelMedium?.copyWith(
                      color: key == value ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: key == value ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «كم يأكل مشمش؟» — the plan, its inputs, and the door to the override.
class FeedingPlanCard extends StatelessWidget {
  const FeedingPlanCard({
    super.key,
    required this.pet,
    required this.plan,
    this.onActivity,
    this.onCondition,
    this.onOverride,
    this.onAddWeight,
    this.busy = false,
  });

  final Pet pet;
  final FeedingPlan? plan;
  final ValueChanged<String>? onActivity;
  final ValueChanged<String>? onCondition;
  final VoidCallback? onOverride;
  final VoidCallback? onAddWeight;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final supported = pet.species == PetSpecies.cat || pet.species == PetSpecies.dog;
    final plan = this.plan;

    Widget body;
    if (!supported) {
      body = _Quiet(text: l.careFeedUnsupported, mark: FamilyMark.bowl);
    } else if (plan == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Quiet(text: l.careFeedNoWeight(pet.name), mark: FamilyMark.scale),
          Gap.h12,
          FilledButton.tonal(
            onPressed: busy ? null : onAddWeight,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            child: Text(l.careFeedAddWeight),
          ),
        ],
      );
    } else {
      final grams = Fmt.number(plan.effectiveGDay, locale: locale, decimals: 0);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.careGramsPerDay(grams),
                      style: context.tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: plan.hasOverride ? ZbTokens.amberDeep : cs.primary,
                        height: 1.1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Gap.h4,
                    Text(
                      plan.hasOverride
                          ? l.careOverrideActive(grams)
                          : l.careFeedKcal(Fmt.number(plan.kcalDay, locale: locale, decimals: 0)),
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _StageChip(text: careStageLabel(l, plan.stage)),
            ],
          ),
          Gap.h12,
          Row(
            children: [
              Expanded(child: _FoodCell(label: l.careFeedDry, grams: plan.dryGDay, locale: locale, l: l, active: !plan.hasOverride)),
              Gap.w8,
              Expanded(child: _FoodCell(label: l.careFeedWet, grams: plan.wetGDay, locale: locale, l: l)),
              Gap.w8,
              Expanded(
                child: _FoodCell(
                  label: l.careFeedMixed,
                  grams: plan.mixedDryGDay,
                  second: plan.mixedWetGDay,
                  locale: locale,
                  l: l,
                ),
              ),
            ],
          ),
          Gap.h12,
          Text(l.careActivity, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          Gap.h4,
          CareSegments(
            value: pet.activity.isEmpty ? 'normal' : pet.activity,
            busy: busy,
            options: [('low', l.careActivityLow), ('normal', l.careActivityNormal), ('high', l.careActivityHigh)],
            onChanged: (v) => onActivity?.call(v),
          ),
          Gap.h8,
          Text(l.careCondition, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          Gap.h4,
          CareSegments(
            value: pet.bodyCondition.isEmpty ? 'ideal' : pet.bodyCondition,
            busy: busy,
            options: [('under', l.careConditionUnder), ('ideal', l.careConditionIdeal), ('over', l.careConditionOver)],
            onChanged: (v) => onCondition?.call(v),
          ),
          for (final note in plan.notes) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FamilyMarkIcon(FamilyMark.bulb, size: 16),
                Gap.w6,
                Expanded(child: Text(note, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
              ],
            ),
          ],
          Gap.h12,
          Row(
            children: [
              const FamilyMarkIcon(FamilyMark.bowl, size: 16),
              Gap.w6,
              Expanded(
                child: Text(
                  l.careFeedGaugeNote,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: busy ? null : onOverride,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                  child: Text(
                    plan.hasOverride ? l.careOverrideReset : l.careOverrideHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return CareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CareHeader(title: l.careFeedTitle(pet.name)),
          Gap.h12,
          body,
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ZbTokens.logoTeal.withValues(alpha: context.isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(ZbTokens.rPill),
        ),
        child: Text(
          text,
          style: context.tt.labelSmall?.copyWith(
            color: context.isDark ? context.cs.onSurface : ZbTokens.tealDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _FoodCell extends StatelessWidget {
  const _FoodCell({required this.label, required this.grams, required this.locale, required this.l, this.second, this.active = false});

  final String label;
  final double grams;
  final double? second;
  final String locale;
  final L l;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final text = second == null
        ? l.careGramsPerDay(Fmt.number(grams, locale: locale, decimals: 0))
        : '${Fmt.number(grams, locale: locale, decimals: 0)} + ${Fmt.number(second!, locale: locale, decimals: 0)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? cs.primary.withValues(alpha: context.isDark ? 0.18 : 0.08) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: active ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          Gap.h4,
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.text, required this.mark});

  final String text;
  final FamilyMark mark;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          FamilyMarkIcon(mark, size: 22),
          Gap.w8,
          Expanded(child: Text(text, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant))),
        ],
      );
}

/// «الوزن» — the latest reading, the trend, the line, and the button.
class WeightCard extends StatelessWidget {
  const WeightCard({
    super.key,
    required this.pet,
    required this.care,
    this.missionPaws,
    this.onLog,
    this.onDelete,
    this.busy = false,
  });

  final Pet pet;
  final PetCare care;

  /// The weigh-in mission's paws, when it is open this month.
  final int? missionPaws;
  final VoidCallback? onLog;
  final ValueChanged<WeightEntry>? onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final latest = care.latestKg;
    final trend = care.trend;
    final entries = care.weights;

    String trendText() {
      if (trend == null) return '';
      final kg = Fmt.number(trend.deltaKg.abs(), locale: locale, decimals: 1);
      final days = Fmt.number(trend.days, locale: locale, decimals: 0);
      return switch (trend.direction) {
        'up' => l.careWeightTrendUp(kg, days),
        'down' => l.careWeightTrendDown(kg, days),
        _ => l.careWeightTrendFlat(days),
      };
    }

    final trendHue = trend == null
        ? cs.onSurfaceVariant
        : (trend.isFlagged ? context.zb.sale : (trend.direction == 'flat' ? ZbTokens.logoTeal : ZbTokens.amberDeep));

    return CareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CareHeader(
            title: l.careWeightTitle,
            trailing: latest == null
                ? null
                : Text(
                    '${Fmt.number(latest, locale: locale, decimals: 1)} ${l.petWeightUnit}',
                    style: context.tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
          if (trend != null) ...[
            Gap.h8,
            Row(
              children: [
                Icon(
                  switch (trend.direction) { 'up' => Icons.north_east_rounded, 'down' => Icons.south_east_rounded, _ => Icons.east_rounded },
                  size: 16,
                  color: trendHue,
                ),
                Gap.w4,
                Expanded(child: Text(trendText(), style: context.tt.labelMedium?.copyWith(color: trendHue, fontWeight: FontWeight.w700))),
              ],
            ),
            if (trend.isFlagged) ...[
              Gap.h4,
              Text(
                trend.flag == 'gain' ? l.careWeightFlagGain : l.careWeightFlagLoss,
                style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
          Gap.h12,
          if (entries.length >= 2)
            SizedBox(
              height: 84,
              child: CustomPaint(
                size: const Size(double.infinity, 84),
                painter: WeightSparkline(
                  values: entries.map((e) => e.kg).toList(),
                  color: cs.primary,
                  grid: cs.outlineVariant,
                  ink: cs.onSurfaceVariant,
                  labels: (Fmt.dateShort(entries.first.on, locale), Fmt.dateShort(entries.last.on, locale)),
                  textScaler: MediaQuery.textScalerOf(context),
                  rtl: context.isRtl,
                ),
              ),
            )
          else
            _Quiet(text: l.careWeightEmpty, mark: FamilyMark.scale),
          Gap.h12,
          FilledButton(
            onPressed: busy ? null : onLog,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(l.careWeightLog, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (missionPaws != null) ...[Gap.w6, const PawCoin(size: 16)],
              ],
            ),
          ),
          if (missionPaws != null) ...[
            const SizedBox(height: 6),
            Text(
              l.careWeightMission(Fmt.number(missionPaws!, locale: locale, decimals: 0)),
              textAlign: TextAlign.center,
              style: context.tt.labelSmall?.copyWith(color: ZbTokens.amberDeep, fontWeight: FontWeight.w700),
            ),
          ],
          if (entries.isNotEmpty) ...[
            Gap.h12,
            for (final entry in entries.reversed.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        Fmt.dateFull(entry.on, locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      '${Fmt.number(entry.kg, locale: locale, decimals: 1)} ${l.petWeightUnit}',
                      style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    if (onDelete != null)
                      IconButton(
                        onPressed: busy ? null : () => onDelete!(entry),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: cs.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A small line chart: the readings joined, the latest one emphasised.
class WeightSparkline extends CustomPainter {
  const WeightSparkline({
    required this.values,
    required this.color,
    required this.grid,
    required this.ink,
    required this.labels,
    required this.textScaler,
    this.rtl = false,
  });

  final List<double> values;
  final Color color;
  final Color grid;
  final Color ink;
  final (String, String) labels;
  final TextScaler textScaler;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const padX = 6.0;
    const top = 8.0;
    const bottom = 20.0;
    final w = size.width - padX * 2;
    final h = size.height - top - bottom;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 0.4) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.2;
      hi = mid + 0.2;
    }
    final span = hi - lo;

    Offset at(int i) {
      final t = i / (values.length - 1);
      final x = padX + (rtl ? (1 - t) : t) * w;
      final y = top + h - ((values[i] - lo) / span) * h;
      return Offset(x, y);
    }

    // Two faint guide lines.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padX, top + h), Offset(padX + w, top + h), gridPaint);
    canvas.drawLine(const Offset(padX, top), Offset(padX + w, top), gridPaint..color = grid.withValues(alpha: 0.5));

    // The area under the line, then the line.
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = at(i - 1);
      final p1 = at(i);
      final c = (p0.dx + p1.dx) / 2;
      path.cubicTo(c, p0.dy, c, p1.dy, p1.dx, p1.dy);
    }
    final area = Path.from(path)
      ..lineTo(at(values.length - 1).dx, top + h)
      ..lineTo(at(0).dx, top + h)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      final last = i == values.length - 1;
      canvas.drawCircle(at(i), last ? 4.2 : 2.6, Paint()..color = last ? color : color.withValues(alpha: 0.6));
      if (last) canvas.drawCircle(at(i), 2.0, Paint()..color = Colors.white);
    }

    // First and last dates under the ends.
    void label(String text, double x, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: ink)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final dx = align == TextAlign.left ? x : x - tp.width;
      tp.paint(canvas, Offset(dx.clamp(0, size.width - tp.width), size.height - tp.height));
    }

    label(labels.$1, at(0).dx, rtl ? TextAlign.right : TextAlign.left);
    label(labels.$2, at(values.length - 1).dx, rtl ? TextAlign.left : TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant WeightSparkline old) =>
      old.values != values || old.color != color || old.rtl != rtl || old.labels != labels;
}

/// One reminder: the mark, the name, the state chip, and «تم».
class CareReminderRow extends StatelessWidget {
  const CareReminderRow({
    super.key,
    required this.reminder,
    this.onDone,
    this.onEdit,
    this.onProduct,
    this.busy = false,
  });

  final CareReminder reminder;
  final VoidCallback? onDone;
  final VoidCallback? onEdit;
  final ValueChanged<ProductCard>? onProduct;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final hue = careHue(context, reminder);
    final quiet = !reminder.isSet || reminder.isOff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hue.withValues(alpha: context.isDark ? 0.20 : (quiet ? 0.08 : 0.12)),
              ),
              alignment: Alignment.center,
              child: FamilyMarkIcon(careMarkOf(reminder.kind), size: 22, color: quiet ? cs.onSurfaceVariant : null),
            ),
            Gap.w12,
            Expanded(
              child: PressScale(
                onTap: busy ? null : onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Gap.h4,
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StateChip(text: careStateLabel(l, reminder), color: hue, filled: reminder.isDueNow),
                        if (reminder.isSet && !reminder.isOff && reminder.nextOn != null)
                          Text(
                            Fmt.dateShort(reminder.nextOn!, locale),
                            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        Text(
                          careIntervalLabel(l, reminder.intervalDays),
                          style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Gap.w8,
            SizedBox(
              height: 36,
              child: FilledButton.tonal(
                onPressed: busy ? null : onDone,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: reminder.isDueNow ? hue : null,
                  foregroundColor: reminder.isDueNow ? Colors.white : null,
                ),
                child: Text(l.actionDone),
              ),
            ),
            IconButton(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.tune_rounded, size: 18),
              color: cs.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              tooltip: l.careEdit,
            ),
          ],
        ),
        if (reminder.products.isNotEmpty && (reminder.needsAttention || !reminder.isSet)) ...[
          Gap.h8,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.careSuggested, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SizedBox(
                  // Two lines of name plus a price, at whatever type size the customer uses.
                  height: MediaQuery.textScalerOf(context).scale(58),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reminder.products.length,
                    separatorBuilder: (_, _) => Gap.w8,
                    itemBuilder: (context, i) => _ProductPill(product: reminder.products[i], onTap: () => onProduct?.call(reminder.products[i])),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.text, required this.color, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.tt.labelSmall?.copyWith(
          color: filled ? Colors.white : (dark ? context.cs.onSurface : Color.lerp(color, ZbTokens.ink, 0.35)),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A product as a small horizontal pill: image, name, price.
class _ProductPill extends StatelessWidget {
  const _ProductPill({required this.product, required this.onTap});

  final ProductCard product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: Container(
        width: 220,
        padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ZbImage(url: product.image, radius: BorderRadius.circular(ZbTokens.rSm), padding: const EdgeInsets.all(2)),
            ),
            Gap.w8,
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
                  const SizedBox(height: 2),
                  Text(Fmt.price(product.price, locale: locale), style: context.tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
