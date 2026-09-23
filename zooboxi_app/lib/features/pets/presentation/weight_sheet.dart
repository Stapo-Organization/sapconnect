import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/characters/characters.dart';
import '../../../core/characters/companion.dart';
import '../../../core/providers.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../loyalty/data/loyalty_repository.dart';
import '../data/household.dart';
import '../data/pet_models.dart';
import '../data/pets_repository.dart';

/// «كم وزن مشمش؟» — asked in its own moment, one question on one sheet: the
/// animal stands on a scale, the reading is big, and the value is set by
/// sliding a ruler the way a real one is read. The weight is what the food
/// gauge and the feeding plan run on.
Future<void> showWeightSheet(BuildContext context, WidgetRef ref, Pet pet) async {
  final saved = await showZbSheet<bool>(context, builder: (_) => _WeightSheet(pet: pet));
  if (saved != true && context.mounted) {
    await ref.read(localStoreProvider).dismissWeightNudge(pet.id);
    ref.invalidate(petsProvider);
  }
}

class _WeightSheet extends ConsumerStatefulWidget {
  const _WeightSheet({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<_WeightSheet> {
  late double _kg;
  bool _saving = false;

  /// The unsnapped value while a finger is on the ruler — a slow drag moves
  /// a fraction of a step per frame, which snapping alone would swallow.
  double _raw = 0;

  bool get _dog => widget.pet.species == PetSpecies.dog;
  double get _step => _dog ? 0.5 : 0.1;
  double get _min => _dog ? 1 : 0.5;
  double get _max => _dog ? 70 : 12;

  /// Screen points per kilogram on the ruler.
  double get _px => _dog ? 14 : 60;

  @override
  void initState() {
    super.initState();
    _kg = widget.pet.weightKg ?? (_dog ? 12 : 4);
  }

  void _set(double kg) {
    final snapped = ((kg / _step).round() * _step).clamp(_min, _max);
    if ((snapped - _kg).abs() < 1e-6) return;
    Haptics.selection();
    setState(() => _kg = double.parse(snapped.toStringAsFixed(1)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final result = await ref.read(petsRepositoryProvider).update(widget.pet.id, widget.pet.copyWith(weightKg: _kg));
      ref.invalidate(petsProvider);
      invalidateLoyalty(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppToast.success(
        context,
        result.pawsEarned > 0
            ? l.pawsEarned(result.pawsEarned, Fmt.number(result.pawsEarned, locale: locale, decimals: 0))
            : l.petSaved,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, errorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final cast = castForSpecies(widget.pet.species) ?? ZbCast.cat;
    final reading = Fmt.number(_kg, locale: locale, decimals: _dog && _kg % 1 == 0 ? 0 : 1);

    return BottomSheetScaffold(
      title: l.weightNudgeTitle(widget.pet.name),
      subtitle: l.weightNudgeBody,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(l.weightSheetSave),
          ),
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(l.weightSheetLater)),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.isDark ? ZbTokens.amberContainerDark : ZbTokens.amberTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.pawsHowProfile,
                style: context.tt.labelSmall?.copyWith(
                  color: context.isDark ? ZbTokens.amberOnDark : ZbTokens.amberDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Gap.h16,
          Text.rich(
            TextSpan(
              text: reading,
              children: [
                TextSpan(
                  text: ' ${l.petWeightUnit}',
                  style: context.tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: context.tt.displaySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
          ),
          Gap.h8,
          // The animal on the scale.
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                const Positioned(bottom: -4, child: ZbGround(width: 230, height: 18)),
                const Positioned(bottom: 0, child: _Scale(width: 200)),
                Positioned(
                  bottom: 26,
                  child: Companion(ZbPose.sitUp, cast: cast, height: 118, idle: ZbIdle.breathe),
                ),
              ],
            ),
          ),
          Gap.h20,
          Semantics(
            slider: true,
            label: l.weightSheetSlider,
            value: '$reading ${l.petWeightUnit}',
            increasedValue: Fmt.number(math.min(_kg + _step, _max), locale: locale, decimals: 1),
            decreasedValue: Fmt.number(math.max(_kg - _step, _min), locale: locale, decimals: 1),
            onIncrease: () => _set(_kg + _step),
            onDecrease: () => _set(_kg - _step),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  _StepButton(icon: Icons.remove_rounded, onTap: () => _set(_kg - _step)),
                  Expanded(
                    child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _raw = _kg,
                onHorizontalDragUpdate: (d) {
                  _raw = (_raw + (context.isRtl ? d.delta.dx : -d.delta.dx) / _px).clamp(_min, _max);
                  _set(_raw);
                },
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RulerPainter(
                      value: _kg,
                      pxPerUnit: _px,
                      minor: _dog ? 1 : 0.1,
                      major: _dog ? 5 : 1,
                      rtl: context.isRtl,
                      ink: cs.onSurface,
                      soft: cs.outlineVariant,
                      pointer: ZbTokens.coral,
                      locale: locale,
                      label: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
                  ),
                  _StepButton(icon: Icons.add_rounded, onTap: () => _set(_kg + _step)),
                ],
              ),
            ),
          ),
          Gap.h8,
        ],
      ),
    );
  }
}

/// The scale the animal stands on — flat teal, the logo's warm-brown outline.
class _Scale extends StatelessWidget {
  const _Scale({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 0.2), painter: _ScalePainter());
}

class _ScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 210;
    canvas.scale(k);
    const ink = Color(0xFF5A2C2F);
    final body = RRect.fromLTRBR(4, 6, 206, 36, const Radius.circular(15));
    canvas.drawRRect(body.inflate(5), Paint()..color = Colors.white);
    canvas.drawRRect(body, Paint()..color = ZbTokens.teal);
    canvas.drawRRect(body, Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    canvas.drawRRect(RRect.fromLTRBR(18, 12, 192, 19, const Radius.circular(3.5)),
        Paint()..color = Colors.white.withValues(alpha: 0.3));
    for (final x in const [30.0, 158.0]) {
      canvas.drawRRect(RRect.fromLTRBR(x, 34, x + 22, 42, const Radius.circular(3)), Paint()..color = ink);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A tape measure under a fixed pointer; values grow toward the end edge.
class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.value,
    required this.pxPerUnit,
    required this.minor,
    required this.major,
    required this.rtl,
    required this.ink,
    required this.soft,
    required this.pointer,
    required this.locale,
    required this.label,
  });

  final double value;
  final double pxPerUnit;
  final double minor;
  final double major;
  final bool rtl;
  final Color ink;
  final Color soft;
  final Color pointer;
  final String locale;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final dir = rtl ? -1.0 : 1.0;
    final span = cx / pxPerUnit + minor;
    final first = ((value - span) / minor).floor();
    final last = ((value + span) / minor).ceil();
    for (var i = first; i <= last; i++) {
      final v = i * minor;
      if (v < 0) continue;
      final x = cx + (v - value) * pxPerUnit * dir;
      final fade = (1 - ((x - cx).abs() / cx)).clamp(0.15, 1.0);
      final isMajor = (v / major - (v / major).round()).abs() < 1e-6;
      final h = isMajor ? 24.0 : 12.0;
      canvas.drawLine(
        Offset(x, 8),
        Offset(x, 8 + h),
        Paint()
          ..color = (isMajor ? ink : soft).withValues(alpha: fade)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: Fmt.number(v, locale: locale, decimals: 0),
            style: label.copyWith(color: label.color?.withValues(alpha: fade)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 38));
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 20), width: 4, height: 40), const Radius.circular(2)),
      Paint()..color = pointer,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => old.value != value || old.rtl != rtl || old.ink != ink;
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      );
}
