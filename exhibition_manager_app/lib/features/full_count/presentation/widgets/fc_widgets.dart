import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Shared pieces of the full-count screens (one look across all of them).
class Fc {
  Fc._();
  static Color get accent => AppDomain.counting.accent;
  static Color get accentDark => AppDomain.counting.accentDark;
  static Color get soft => AppDomain.counting.soft;

  /// Colour per kind of display unit — matches the printed label stripe.
  /// Used only as that thin stripe, never as a fill.
  static Color kindColor(String kind) {
    switch (kind) {
      case 'gondola':
        return const Color(0xFF0B7D57);
      case 'wall':
        return const Color(0xFF4F46E5);
      case 'endcap':
        return AppColors.warning;
      case 'cashier':
        return const Color(0xFF13141D);
      case 'backroom':
        return const Color(0xFFC2410C);
      default:
        return const Color(0xFF585C6C);
    }
  }

  static String kindLabel(BuildContext context, String kind) => context.tr('fc_kind_$kind');

  static String qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static void toast(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.error : AppColors.textPrimary,
      ));
  }
}

/// The unit code as printed on its shelf label (G04, W01 …): ink mono code on
/// a white tile, with the label's kind-colour stripe on the leading edge so
/// the screen and the sticker read as the same thing.
class UnitBadge extends StatelessWidget {
  final String code;
  final String kind;
  final double size;
  const UnitBadge({super.key, required this.code, required this.kind, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.2);
    return Container(
      width: size,
      height: size * 0.84,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: r,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: Fc.kindColor(kind)),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(code,
                      textDirection: TextDirection.ltr,
                      style: AppTypography.mono.copyWith(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: size * 0.3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small white card section used across the full-count screens.
class FcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  const FcCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.base), this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

class FcSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const FcSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Big phone-style keypad: digits, backspace and a «+ كرتون» key.
class CountKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onCarton;

  const CountKeypad({super.key, required this.onDigit, required this.onBackspace, this.onCarton});

  @override
  Widget build(BuildContext context) {
    final h = context.byWidth(regular: 54.0, compact: 44.0, tiny: 40.0);
    Widget key(Widget child, VoidCallback? onTap, {Color? bg, String? semantics}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Semantics(
              button: true,
              label: semantics,
              child: Material(
                color: bg ?? AppColors.surfaceVariant,
                borderRadius: AppRadius.borderMd,
                child: InkWell(
                  borderRadius: AppRadius.borderMd,
                  onTap: onTap == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onTap();
                        },
                  child: SizedBox(height: h, child: Center(child: child)),
                ),
              ),
            ),
          ),
        );
    Widget digit(String d) => key(
        Text(d, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        () => onDigit(d));

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [digit('1'), digit('2'), digit('3')]),
          Row(children: [digit('4'), digit('5'), digit('6')]),
          Row(children: [digit('7'), digit('8'), digit('9')]),
          Row(children: [
            key(Icon(Icons.backspace_outlined, color: AppColors.textSecondary), onBackspace,
                semantics: context.tr('fc_backspace')),
            digit('0'),
            key(
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(context.tr('fc_add_carton'),
                    style: AppTypography.labelLarge.copyWith(color: Fc.accentDark, fontWeight: FontWeight.w700)),
              ),
              onCarton,
              bg: Fc.soft,
            ),
          ]),
        ],
      ),
    );
  }
}

/// Cartons × pack + loose pieces → total pieces. Returns null when cancelled.
class CartonEntry {
  final double cartons;
  final double packSize;
  final double loose;
  const CartonEntry(this.cartons, this.packSize, this.loose);
  double get total => cartons * packSize + loose;
}

Future<CartonEntry?> showCartonSheet(BuildContext context,
    {required String productName, double? packSize, bool scannedCarton = false}) {
  return showModalBottomSheet<CartonEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: _CartonSheet(productName: productName, packSize: packSize, scannedCarton: scannedCarton),
      ),
    ),
  );
}

class _CartonSheet extends StatefulWidget {
  final String productName;
  final double? packSize;
  final bool scannedCarton;
  const _CartonSheet({required this.productName, this.packSize, required this.scannedCarton});
  @override
  State<_CartonSheet> createState() => _CartonSheetState();
}

class _CartonSheetState extends State<_CartonSheet> {
  late int _cartons = widget.scannedCarton ? 1 : 0;
  int _loose = 0;
  late final TextEditingController _pack =
      TextEditingController(text: widget.packSize != null ? Fc.qty(widget.packSize!) : '');

  double get _packSize => double.tryParse(_pack.text.trim()) ?? 0;

  @override
  void dispose() {
    _pack.dispose();
    super.dispose();
  }

  Widget _stepper(String label, String hint, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
            Text(hint, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          ]),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(children: [
            _roundBtn(Icons.remove_rounded, value > 0 ? () => onChanged(value - 1) : null, filled: false),
            SizedBox(
              width: 48,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
            ),
            _roundBtn(Icons.add_rounded, () => onChanged(value + 1)),
          ]),
        ),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback? onTap, {bool filled = true}) => SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: filled ? Fc.accentDark : AppColors.surfaceVariant,
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: Icon(icon, color: filled ? Colors.white : AppColors.textPrimary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = _cartons * _packSize + _loose;
    return BottomSheetScaffold(
      title: widget.scannedCarton ? context.tr('fc_carton_scanned') : context.tr('fc_carton_title'),
      subtitle: widget.productName,
      icon: Icons.inventory_2_outlined,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(context.tr('fc_pack_size'), style: AppTypography.bodyMedium)),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _pack,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    suffixText: context.tr('fc_pcs'),
                    border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            FcCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(children: [
                _stepper(context.tr('fc_sealed_cartons'), context.tr('fc_sealed_cartons_hint'), _cartons,
                    (v) => setState(() => _cartons = v)),
                Divider(height: AppSpacing.xl, color: AppColors.borderLight),
                _stepper(context.tr('fc_loose_pieces'), context.tr('fc_loose_pieces_hint'), _loose,
                    (v) => setState(() => _loose = v)),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(color: Fc.soft, borderRadius: AppRadius.borderXl),
              child: Row(children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('$_cartons × ${Fc.qty(_packSize)} + $_loose',
                        textDirection: TextDirection.ltr,
                        style: AppTypography.bodyMedium.copyWith(color: Fc.accentDark)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(Fc.qty(total),
                    style: AppTypography.headlineMedium.copyWith(color: Fc.accentDark, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text(context.tr('fc_pcs'), style: AppTypography.titleSmall.copyWith(color: Fc.accentDark)),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(context.tr('fc_open_carton_rule'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: context.tr('fc_record_pcs').replaceAll('{n}', Fc.qty(total)),
              icon: Icons.check_rounded,
              color: Fc.accentDark,
              onPressed: _packSize > 0 && (_cartons > 0 || _loose > 0)
                  ? () => Navigator.pop(context, CartonEntry(_cartons.toDouble(), _packSize, _loose.toDouble()))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
