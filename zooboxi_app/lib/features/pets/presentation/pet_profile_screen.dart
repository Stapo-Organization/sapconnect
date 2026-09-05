import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../catalog/data/product_models.dart';
import '../../loyalty/data/loyalty_models.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../loyalty/presentation/widgets/supply_card.dart';
import '../data/care_models.dart';
import '../data/pet_models.dart';
import '../data/pets_repository.dart';
import 'widgets/care_widgets.dart';
import 'widgets/pet_card.dart' show speciesLabel;
import 'widgets/species_avatar.dart';

/// «الرفيق» — one animal's page: how much it eats, what it weighs, what it
/// is due for, and what is running out.
///
/// Every number is the server's. The screen's own job is to make the three
/// honest answers a customer can give — a weight, «تم», a different amount —
/// one tap each, because each tap makes the food gauge more theirs.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({super.key, required this.petId, this.initial});

  final int petId;

  /// The card that was tapped, so the header paints on frame one.
  final Pet? initial;

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(petCareProvider(widget.petId));
    ref.invalidate(petsProvider);
    invalidateLoyalty(ref);
  }

  /// Run one write, show its outcome, refresh everything that reads pets.
  Future<PetCare?> _write(Future<PetCare> Function() call, {String? success}) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final result = await call();
      if (!mounted) return result;
      _refresh();
      if (success != null) AppToast.success(context, success);
      return result;
    } catch (e) {
      if (mounted) AppToast.error(context, errorMessage(context, e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _track(String type, Map<String, Object?> payload) {
    ref.read(eventsBufferProvider).track(ZbEvent(type: type, zone: 'pet_profile', payload: {'pet_id': widget.petId, ...payload}));
  }

  // ── plan inputs ──

  Future<void> _setActivity(String value) async {
    Haptics.selection();
    await _write(() async {
      await ref.read(petsRepositoryProvider).updatePlanInputs(widget.petId, activity: value);
      return ref.read(petsRepositoryProvider).care(widget.petId);
    });
  }

  Future<void> _setCondition(String value) async {
    Haptics.selection();
    await _write(() async {
      await ref.read(petsRepositoryProvider).updatePlanInputs(widget.petId, bodyCondition: value);
      return ref.read(petsRepositoryProvider).care(widget.petId);
    });
  }

  Future<void> _override(PetCare care) async {
    final plan = care.plan;
    if (plan == null) return;
    if (plan.hasOverride) {
      await _write(() async {
        await ref.read(petsRepositoryProvider).updatePlanInputs(widget.petId, clearFeedGDay: true);
        return ref.read(petsRepositoryProvider).care(widget.petId);
      }, success: L.of(context).careSaved);
      return;
    }
    final grams = await showZbSheet<double>(
      context,
      builder: (_) => _GramsSheet(pet: care.pet, start: plan.effectiveGDay),
    );
    if (grams == null || !mounted) return;
    _track(ZbEvents.careAction, {'action': 'override', 'grams': grams});
    await _write(() async {
      await ref.read(petsRepositoryProvider).updatePlanInputs(widget.petId, feedGDay: grams);
      return ref.read(petsRepositoryProvider).care(widget.petId);
    }, success: L.of(context).careSaved);
  }

  // ── weight ──

  Future<void> _logWeight(PetCare care) async {
    final picked = await showZbSheet<(double, DateTime)>(
      context,
      builder: (_) => _WeightSheet(pet: care.pet, start: care.latestKg ?? 4.0),
    );
    if (picked == null || !mounted) return;
    final (kg, on) = picked;
    final result = await _write(() => ref.read(petsRepositoryProvider).logWeight(widget.petId, kg, on: on));
    if (result == null || !mounted) return;
    _track(ZbEvents.weightLogged, {'kg': kg});
    unawaited(Haptics.success());
    final l = L.of(context);
    if (result.pawsEarned > 0) {
      final locale = Localizations.localeOf(context).languageCode;
      AppToast.success(context, l.pawsEarned(result.pawsEarned, Fmt.number(result.pawsEarned, locale: locale, decimals: 0)));
    } else {
      AppToast.success(context, l.careWeightSaved);
    }
  }

  Future<void> _deleteWeight(WeightEntry entry) async {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.careWeightDeleteConfirm(Fmt.dateShort(entry.on, locale))),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.cs.error),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _write(() => ref.read(petsRepositoryProvider).deleteWeight(widget.petId, entry.id));
  }

  // ── reminders ──

  Future<void> _done(CareReminder reminder) async {
    final result = await _write(() => ref.read(petsRepositoryProvider).markDone(widget.petId, reminder.kind));
    if (result == null || !mounted) return;
    _track(ZbEvents.careAction, {'kind': reminder.kind, 'action': 'done'});
    unawaited(Haptics.success());
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    CareReminder? fresh;
    for (final r in result.reminders) {
      if (r.kind == reminder.kind) fresh = r;
    }
    AppToast.success(context, fresh?.nextOn != null ? l.careDoneToast(Fmt.dateShort(fresh!.nextOn!, locale)) : l.careSaved);
  }

  Future<void> _editReminder(CareReminder reminder) async {
    final edit = await showZbSheet<_ReminderEdit>(
      context,
      builder: (_) => _ReminderSheet(reminder: reminder),
    );
    if (edit == null || !mounted) return;
    _track(ZbEvents.careAction, {'kind': reminder.kind, 'action': 'set'});
    await _write(
      () => ref.read(petsRepositoryProvider).setReminder(
            widget.petId,
            reminder.kind,
            lastOn: edit.lastOn,
            intervalDays: edit.intervalDays,
            enabled: edit.enabled,
          ),
      success: L.of(context).careSaved,
    );
  }

  Future<void> _openProduct(CareReminder reminder, ProductCard product) async {
    _track(ZbEvents.careAction, {'kind': reminder.kind, 'action': 'product', 'product_id': product.id});
    Haptics.light();
    await context.push<void>('/product/${product.id}', extra: product);
  }

  // ── supply ──

  Future<void> _orderSupply(SupplyItem item) async {
    if (_busy) return;
    _track(ZbEvents.supplyAction, {'product_id': item.product.id, 'action': 'order'});
    if (item.product.isVariable && item.variationId <= 0) {
      Haptics.light();
      await context.push<void>('/product/${item.product.id}', extra: item.product);
      return;
    }
    setState(() => _busy = true);
    await addToCart(
      context,
      ref,
      product: item.product,
      variationId: item.variationId > 0 ? item.variationId : null,
      quantity: item.qtyLast,
      zone: 'pet_profile',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final care = ref.watch(petCareProvider(widget.petId));
    final summary = ref.watch(loyaltySummaryProvider).value;
    final name = care.value?.pet.name ?? widget.initial?.name ?? '';

    int? missionPaws;
    if (summary != null && summary.care.weighIn) {
      for (final m in summary.missions.items) {
        if (m.kind == 'care' && !m.isDone) missionPaws = m.reward.paws;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: l.careEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/pets/${widget.petId}/edit', extra: care.value?.pet ?? widget.initial),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(petCareProvider(widget.petId));
          await ref.read(petCareProvider(widget.petId).future);
        },
        child: AsyncView<PetCare?>(
          value: care,
          onRetry: () => ref.invalidate(petCareProvider(widget.petId)),
          skeleton: _Skeleton(pet: widget.initial),
          builder: (data) {
            if (data == null) {
              return EmptyState(
                icon: Icons.pets_rounded,
                title: l.familyGuestTitle,
                message: l.familyGuestBody,
                actionLabel: l.familyGuestCta,
                onAction: () => showAuthSheet(context, reason: l.familyGuestBody),
                mascot: true,
              );
            }
            return _Body(
              care: data,
              busy: _busy,
              missionPaws: missionPaws,
              onTimePct: summary?.supply.onTimePct ?? 20,
              onActivity: _setActivity,
              onCondition: _setCondition,
              onOverride: () => _override(data),
              onLogWeight: () => _logWeight(data),
              onDeleteWeight: _deleteWeight,
              onDone: _done,
              onEditReminder: _editReminder,
              onProduct: _openProduct,
              onOrderSupply: _orderSupply,
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.care,
    required this.busy,
    required this.missionPaws,
    required this.onTimePct,
    required this.onActivity,
    required this.onCondition,
    required this.onOverride,
    required this.onLogWeight,
    required this.onDeleteWeight,
    required this.onDone,
    required this.onEditReminder,
    required this.onProduct,
    required this.onOrderSupply,
  });

  final PetCare care;
  final bool busy;
  final int? missionPaws;
  final int onTimePct;
  final ValueChanged<String> onActivity;
  final ValueChanged<String> onCondition;
  final VoidCallback onOverride;
  final VoidCallback onLogWeight;
  final ValueChanged<WeightEntry> onDeleteWeight;
  final ValueChanged<CareReminder> onDone;
  final ValueChanged<CareReminder> onEditReminder;
  final void Function(CareReminder, ProductCard) onProduct;
  final ValueChanged<SupplyItem> onOrderSupply;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pet = care.pet;
    final still = context.reduceMotion;

    var i = 0;
    Widget enter(Widget child) {
      if (still) return child;
      final delay = Duration(milliseconds: 55 * i++);
      return child
          .animate(delay: delay)
          .fadeIn(duration: Motion.enter, curve: Motion.decelerate)
          .slideY(begin: 0.05, end: 0, duration: Motion.enter, curve: Motion.decelerate);
    }

    // Due reminders lead; the rest keep their fixed order.
    final reminders = [...care.reminders]..sort((a, b) {
        int rank(CareReminder r) => r.isDueNow ? 0 : (r.state == 'soon' ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        enter(_Header(pet: pet)),
        Gap.h16,
        enter(
          FeedingPlanCard(
            pet: pet,
            plan: care.plan,
            busy: busy,
            onActivity: onActivity,
            onCondition: onCondition,
            onOverride: onOverride,
            onAddWeight: onLogWeight,
          ),
        ),
        Gap.h12,
        enter(
          WeightCard(
            pet: pet,
            care: care,
            busy: busy,
            missionPaws: missionPaws,
            onLog: onLogWeight,
            onDelete: onDeleteWeight,
          ),
        ),
        Gap.h12,
        enter(
          CareCard(
            accent: ZbTokens.logoCoral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CareHeader(title: l.careRemindersTitle, subtitle: l.careRemindersSubtitle),
                Gap.h12,
                for (var k = 0; k < reminders.length; k++) ...[
                  if (k > 0) Divider(height: 20, color: context.cs.outlineVariant),
                  CareReminderRow(
                    reminder: reminders[k],
                    busy: busy,
                    onDone: () => onDone(reminders[k]),
                    onEdit: () => onEditReminder(reminders[k]),
                    onProduct: (p) => onProduct(reminders[k], p),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (care.supply.isNotEmpty) ...[
          Gap.h20,
          enter(
            CareHeader(
              title: l.careSupplyTitle(pet.name),
              trailing: TextButton(
                onPressed: () => context.push('/family/supply'),
                child: Text(l.careSupplyAll),
              ),
            ),
          ),
          Gap.h8,
          for (final item in care.supply) ...[
            enter(
              SupplyGaugeCard(
                item: item,
                compact: true,
                busy: busy,
                onTimePct: onTimePct,
                onOrder: () => onOrderSupply(item),
              ),
            ),
            Gap.h12,
          ],
        ],
      ],
    );
  }
}

/// The portrait on the species' wash, the name, and the facts.
class _Header extends StatelessWidget {
  const _Header({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final art = SpeciesArt.of(pet.species);
    final facts = <String>[
      speciesLabel(l, pet.species),
      if (pet.breed.isNotEmpty) pet.breed,
      if ((pet.ageLabel ?? '').isNotEmpty) pet.ageLabel!,
      if (pet.sex == 'm') l.petSexMale,
      if (pet.sex == 'f') l.petSexFemale,
      if (pet.neutered == true) l.petFieldNeutered,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: context.isDark
              ? [art.shade.withValues(alpha: 0.28), art.shade.withValues(alpha: 0.10)]
              : [art.well, Color.lerp(art.well, cs.surface, 0.6)!],
        ),
        borderRadius: BorderRadius.circular(ZbTokens.rXl),
        border: Border.all(color: art.shade.withValues(alpha: context.isDark ? 0.35 : 0.25)),
      ),
      child: Row(
        children: [
          SpeciesAvatar(species: pet.species, photoUrl: pet.photoUrl, size: 84, showWell: false),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                ),
                Gap.h8,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final fact in facts) _Fact(text: fact, ink: art.shade),
                  ],
                ),
                if (!pet.isComplete) ...[
                  Gap.h8,
                  Row(
                    children: [
                      const PawCoin(size: 16),
                      Gap.w4,
                      Expanded(
                        child: Text(
                          l.petIncompleteHint,
                          style: context.tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                if (pet.isBirthdaySoon) ...[
                  Gap.h8,
                  Row(
                    children: [
                      const FamilyMarkIcon(FamilyMark.cake, size: 16),
                      Gap.w4,
                      Expanded(
                        child: Text(
                          l.petBirthdaySoon(pet.birthdayInDays ?? 0),
                          style: context.tt.labelSmall?.copyWith(color: context.zb.sale, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.text, required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? ink.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Text(
        text,
        style: context.tt.labelSmall?.copyWith(
          color: dark ? context.cs.onSurface : Color.lerp(ink, ZbTokens.ink, 0.45),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.pet});

  final Pet? pet;

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pet != null) _Header(pet: pet!) else const SkeletonBox(height: 116, radius: ZbTokens.rXl),
            Gap.h16,
            const SkeletonBox(height: 250, radius: ZbTokens.rXl),
            Gap.h12,
            const SkeletonBox(height: 200, radius: ZbTokens.rXl),
            Gap.h12,
            const SkeletonBox(height: 320, radius: ZbTokens.rXl),
          ],
        ),
      );
}

/* ══════════════════════════════════════════════════════════════════════
   SHEETS
   ══════════════════════════════════════════════════════════════════════ */

/// A big number with minus/plus around it — weight and grams share it.
class _BigStepper extends StatelessWidget {
  const _BigStepper({required this.text, required this.onStep, this.large = 1, this.small = 0.1});

  final String text;
  final ValueChanged<double> onStep;
  final double large;
  final double small;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    Widget button(IconData icon, double delta, {bool tonal = false}) => SizedBox(
          width: 48,
          height: 48,
          child: tonal
              ? IconButton.filledTonal(onPressed: () => onStep(delta), icon: Icon(icon, size: 20))
              : IconButton.outlined(onPressed: () => onStep(delta), icon: Icon(icon, size: 20)),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        button(Icons.keyboard_double_arrow_down_rounded, -large),
        Gap.w8,
        button(Icons.remove_rounded, -small, tonal: true),
        Gap.w16,
        Text(
          text,
          style: context.tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Gap.w16,
        button(Icons.add_rounded, small, tonal: true),
        Gap.w8,
        button(Icons.keyboard_double_arrow_up_rounded, large),
      ],
    );
  }
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.pet, required this.start});

  final Pet pet;
  final double start;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late double _kg = widget.start.clamp(0.1, 200.0);
  DateTime _on = DateTime.now();

  void _step(double delta) {
    Haptics.selection();
    setState(() => _kg = (((_kg + delta) * 10).round() / 10).clamp(0.1, 200.0));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _on,
      firstDate: DateTime(now.year - 5, now.month, now.day),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _on = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    return BottomSheetScaffold(
      title: l.careWeightLogTitle(widget.pet.name),
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop((_kg, _on)),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(l.actionSave),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap.h8,
          _BigStepper(
            text: '${Fmt.number(_kg, locale: locale, decimals: 1, trimZeros: false)} ${l.petWeightUnit}',
            onStep: _step,
          ),
          Gap.h16,
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text('${l.careWeightPickDate} · ${Fmt.dateFull(_on, locale)}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: cs.onSurface),
          ),
          Gap.h16,
        ],
      ),
    );
  }
}

class _GramsSheet extends StatefulWidget {
  const _GramsSheet({required this.pet, required this.start});

  final Pet pet;
  final double start;

  @override
  State<_GramsSheet> createState() => _GramsSheetState();
}

class _GramsSheetState extends State<_GramsSheet> {
  late double _grams = widget.start.clamp(5.0, 2000.0);

  void _step(double delta) {
    Haptics.selection();
    setState(() => _grams = ((_grams + delta) / 5).round() * 5.0.clamp(5.0, 2000.0));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return BottomSheetScaffold(
      title: l.careOverrideTitle(widget.pet.name),
      subtitle: l.careOverrideBody,
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop(_grams),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(l.actionSave),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap.h8,
          _BigStepper(
            text: l.careGramsPerDay(Fmt.number(_grams, locale: locale, decimals: 0)),
            onStep: _step,
            large: 25,
            small: 5,
          ),
          Gap.h16,
        ],
      ),
    );
  }
}

/// What the reminder sheet hands back.
class _ReminderEdit {
  const _ReminderEdit({this.lastOn, required this.intervalDays, required this.enabled});

  final DateTime? lastOn;
  final int intervalDays;
  final bool enabled;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.reminder});

  final CareReminder reminder;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  static const _intervals = [7, 14, 30, 60, 90, 180, 365];

  late DateTime? _last = widget.reminder.lastOn;
  late int _interval = widget.reminder.intervalDays;
  late bool _enabled = widget.reminder.isSet ? widget.reminder.enabled : true;

  DateTime? get _next => _last?.add(Duration(days: _interval));

  Future<void> _pickLast() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _last ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _last = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final r = widget.reminder;
    final choices = {..._intervals, _interval}.toList()..sort();
    final canSave = _last != null || r.isSet;

    return BottomSheetScaffold(
      title: l.careSetTitle(r.label, r.pet.name),
      subtitle: l.careSetHint,
      footer: FilledButton(
        onPressed: canSave
            ? () => Navigator.of(context).pop(_ReminderEdit(lastOn: _last, intervalDays: _interval, enabled: _enabled))
            : null,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(l.actionSave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap.h8,
          Text(l.careLastOn, style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          Gap.h8,
          OutlinedButton.icon(
            onPressed: _pickLast,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(_last == null ? l.petNotSet : Fmt.dateFull(_last!, locale)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), foregroundColor: cs.onSurface, alignment: AlignmentDirectional.centerStart),
          ),
          Gap.h16,
          Text(l.careInterval, style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          Gap.h8,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final days in choices)
                ChoiceChip(
                  label: Text(careIntervalLabel(l, days)),
                  selected: days == _interval,
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _interval = days);
                  },
                ),
            ],
          ),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.careNextOn, style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    Gap.h4,
                    Text(
                      _next == null ? '—' : Fmt.dateFull(_next!, locale),
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
                    ),
                  ],
                ),
              ),
              Text(l.careEnabled, style: context.tt.labelMedium),
              Gap.w8,
              Switch.adaptive(
                value: _enabled,
                onChanged: (v) {
                  Haptics.selection();
                  setState(() => _enabled = v);
                },
              ),
            ],
          ),
          Gap.h16,
        ],
      ),
    );
  }
}
