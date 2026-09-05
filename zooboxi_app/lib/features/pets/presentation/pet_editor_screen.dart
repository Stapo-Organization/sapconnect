import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/analytics/events_buffer.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/motion/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../data/pet_models.dart';
import '../data/pets_repository.dart';
import 'widgets/pet_card.dart' show speciesLabel;
import 'widgets/species_avatar.dart';

/// Create or edit one pet.
///
/// The species is picked from drawn portraits rather than a dropdown, because
/// "which of these is my animal" is a question the eye answers instantly and a
/// list of words does not. Everything below it is optional except the name —
/// the profile is worth paws precisely so it can be filled in over time rather
/// than demanded at once.
class PetEditorScreen extends ConsumerStatefulWidget {
  const PetEditorScreen({super.key, this.petId, this.initial});

  /// Null for a new pet.
  final int? petId;

  /// The card that was tapped, so the form paints filled on frame one.
  final Pet? initial;

  @override
  ConsumerState<PetEditorScreen> createState() => _PetEditorScreenState();
}

class _PetEditorScreenState extends ConsumerState<PetEditorScreen> {
  /// The one hard bound the form enforces on its own; anything inside it is
  /// the server's to accept or refuse.
  static const double _minWeight = 0.1;
  static const double _maxWeight = 200;

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();

  late PetSpecies _species;
  late String _sex;
  double? _weight;
  DateTime? _birthDate;
  bool _neutered = false;

  String? _nameError;
  String? _weightError;
  String? _birthDateError;
  bool _saving = false;

  bool get _isNew => widget.petId == null;

  @override
  void initState() {
    super.initState();
    final pet = widget.initial;
    _species = pet?.species ?? PetSpecies.cat;
    _sex = pet?.sex ?? '';
    _weight = pet?.weightKg;
    _birthDate = pet?.birthDate;
    _neutered = pet?.neutered ?? false;
    _nameController.text = pet?.name ?? '';
    _breedController.text = pet?.breed ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  /// Returns true when the form is worth sending. Every message is a field
  /// message — a form that fails with one banner makes the customer hunt.
  bool _validate() {
    final l = L.of(context);
    final name = _nameController.text.trim();
    final weight = _weight;

    setState(() {
      _nameError = name.isEmpty ? l.petNameRequired : null;
      _weightError = weight != null && (weight < _minWeight || weight > _maxWeight)
          ? l.petWeightInvalid
          : null;
      _birthDateError =
          _birthDate != null && _birthDate!.isAfter(DateTime.now())
              ? l.petBirthDateInvalid
              : null;
    });

    return _nameError == null && _weightError == null && _birthDateError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    Haptics.light();
    setState(() => _saving = true);

    final draft = Pet(
      id: widget.petId ?? 0,
      name: _nameController.text.trim(),
      species: _species,
      breed: _breedController.text.trim(),
      sex: _sex,
      weightKg: _weight,
      birthDate: _birthDate,
      neutered: _neutered,
    );

    try {
      final repository = ref.read(petsRepositoryProvider);
      final result = _isNew
          ? await repository.create(draft)
          : await repository.update(widget.petId!, draft);

      if (_isNew) {
        ref.read(eventsBufferProvider).track(
              ZbEvent(
                type: ZbEvents.petAdded,
                zone: 'pets',
                payload: {'species': _species.key},
              ),
            );
      }
      ref.invalidate(petsProvider);
      invalidateLoyalty(ref);

      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      final l = L.of(context);
      if (result.pawsEarned > 0) {
        AppToast.success(
          context,
          l.pawsEarned(
            result.pawsEarned,
            Fmt.number(result.pawsEarned, locale: locale, decimals: 0),
          ),
        );
      } else {
        AppToast.success(context, l.petSaved);
      }
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, errorMessage(context, e));
    }
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final name = _nameController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.petDeleteConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.cs.error),
            child: Text(l.petDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(petsRepositoryProvider).remove(widget.petId!);
      ref.invalidate(petsProvider);
      invalidateLoyalty(ref);
      if (!mounted) return;
      AppToast.info(context, l.petDeleted);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, errorMessage(context, e));
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
      helpText: L.of(context).petPickDate,
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateError = null;
    });
  }

  void _stepWeight(double delta) {
    Haptics.selection();
    final base = _weight ?? 4.0;
    final next = ((base + delta) * 10).round() / 10;
    setState(() {
      _weight = next.clamp(_minWeight, _maxWeight);
      _weightError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? l.petNewTitle
              : l.petEditFormTitle(widget.initial?.name ?? _nameController.text.trim()),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _Label(text: l.petFieldSpecies),
                Gap.h8,
                _SpeciesPicker(
                  value: _species,
                  onChanged: (species) {
                    Haptics.selection();
                    setState(() => _species = species);
                  },
                ),
                Gap.h20,

                _Label(text: l.petFieldName),
                Gap.h8,
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: l.petFieldNameHint,
                    errorText: _nameError,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                Gap.h16,

                _Label(text: l.petFieldBreed),
                Gap.h8,
                TextField(
                  controller: _breedController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: l.petFieldBreedHint),
                ),
                Gap.h20,

                _Label(text: l.petFieldWeight),
                Gap.h8,
                _WeightField(
                  weight: _weight,
                  error: _weightError,
                  onStep: _stepWeight,
                  onClear: () => setState(() {
                    _weight = null;
                    _weightError = null;
                  }),
                ),
                Gap.h20,

                _Label(text: l.petFieldBirthDate),
                Gap.h8,
                _PickerRow(
                  icon: Icons.cake_outlined,
                  label: _birthDate == null
                      ? l.petNotSet
                      : Fmt.dateFull(_birthDate!, locale),
                  muted: _birthDate == null,
                  error: _birthDateError,
                  onTap: _pickBirthDate,
                ),
                Gap.h20,

                _Label(text: l.petFieldSex),
                Gap.h8,
                _SexPicker(
                  value: _sex,
                  onChanged: (value) {
                    Haptics.selection();
                    setState(() => _sex = value);
                  },
                ),
                Gap.h16,

                _SwitchRow(
                  label: l.petFieldNeutered,
                  value: _neutered,
                  onChanged: (value) {
                    Haptics.selection();
                    setState(() => _neutered = value);
                  },
                ),

                if (!_isNew) ...[
                  Gap.h24,
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(l.petDelete),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                  ),
                ],
              ],
            ),
          ),
          // Full width on purpose: a Column centres its children, and a bar
          // that shrinks to its button leaves the screen showing through on
          // either side of it.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.actionSave),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          text,
          style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant),
        ),
      );
}

/// Seven drawn portraits in a row. The selected one keeps its ring and its
/// name; the rest stay quiet.
class _SpeciesPicker extends StatelessWidget {
  const _SpeciesPicker({required this.value, required this.onChanged});

  final PetSpecies value;
  final ValueChanged<PetSpecies> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: PetSpecies.values.length,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (context, index) {
          final species = PetSpecies.values[index];
          final selected = species == value;
          return PressScale(
            onTap: () => onChanged(species),
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            child: SizedBox(
              width: 70,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.0 : 0.92,
                    duration: Motion.select,
                    curve: Motion.spring,
                    child: SpeciesAvatar(species: species, size: 66, selected: selected),
                  ),
                  Gap.h4,
                  Text(
                    speciesLabel(l, species),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelSmall?.copyWith(
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Weight in 100-gram steps — the granularity a food counter needs and the
/// one a kitchen scale gives.
class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.weight,
    required this.onStep,
    required this.onClear,
    this.error,
  });

  final double? weight;
  final String? error;
  final ValueChanged<double> onStep;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(ZbTokens.rMd),
            border: Border.all(color: error == null ? cs.outlineVariant : cs.error),
          ),
          padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  weight == null
                      ? l.petNotSet
                      : '${Fmt.number(weight!, locale: locale, decimals: 1, trimZeros: false)} ${l.petWeightUnit}',
                  style: context.tt.bodyLarge?.copyWith(
                    color: weight == null ? cs.onSurfaceVariant : cs.onSurface,
                    fontWeight: weight == null ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
              ),
              if (weight != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: cs.onSurfaceVariant,
                  tooltip: l.actionClear,
                ),
              IconButton.filledTonal(
                onPressed: () => onStep(-0.1),
                icon: const Icon(Icons.remove_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              Gap.w8,
              IconButton.filledTonal(
                onPressed: () => onStep(0.1),
                icon: const Icon(Icons.add_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Text(
              error!,
              style: context.tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.error,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZbTokens.rMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZbTokens.rMd),
                border: Border.all(color: error == null ? cs.outlineVariant : cs.error),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: cs.onSurfaceVariant),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      label,
                      style: context.tt.bodyLarge?.copyWith(
                        color: muted ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    context.isRtl
                        ? Icons.keyboard_arrow_left_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Text(
              error!,
              style: context.tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

class _SexPicker extends StatelessWidget {
  const _SexPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final options = [
      ('m', l.petSexMale),
      ('f', l.petSexFemale),
      ('', l.petSexUnset),
    ];

    return Row(
      children: [
        for (final (key, label) in options) ...[
          Expanded(
            child: PressScale(
              onTap: () => onChanged(key),
              borderRadius: BorderRadius.circular(ZbTokens.rPill),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == key
                      ? cs.primary.withValues(alpha: context.isDark ? 0.22 : 0.12)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                  border: Border.all(
                    color: value == key ? cs.primary : cs.outlineVariant,
                    width: value == key ? 1.6 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: context.tt.labelLarge?.copyWith(
                    color: value == key ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: value == key ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (key != '') Gap.w8,
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      height: 52,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.tt.bodyLarge)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
