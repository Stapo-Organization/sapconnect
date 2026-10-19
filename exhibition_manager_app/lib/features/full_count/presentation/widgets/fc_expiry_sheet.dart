import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import '../../data/full_count_models.dart';
import 'fc_widgets.dart';

/// Asks what the packs of one count line say. One tap on a date saves the
/// whole quantity on it: SAP's batch dates for this showroom come first, then
/// what this counter picked last time for the item, then «other date» (month +
/// year, the way pet food packs print it). «Several dates» splits the quantity.
///
/// Returns the splits ([] = the packs carry no date) or null when dismissed.
Future<List<ExpirySplit>?> showExpirySheet(
  BuildContext context, {
  required String productName,
  required double quantity,
  List<ExpiryOption> options = const [],
  List<ExpirySplit> last = const [],
}) {
  return showModalBottomSheet<List<ExpirySplit>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
      child: SingleChildScrollView(
        child: _ExpirySheet(productName: productName, quantity: quantity, options: options, last: last),
      ),
    ),
  );
}

class _ExpirySheet extends StatefulWidget {
  final String productName;
  final double quantity;
  final List<ExpiryOption> options;
  final List<ExpirySplit> last;
  const _ExpirySheet({required this.productName, required this.quantity, required this.options, required this.last});
  @override
  State<_ExpirySheet> createState() => _ExpirySheetState();
}

class _ExpirySheetState extends State<_ExpirySheet> {
  bool _split = false;
  bool _picker = false;
  late int _year = DateTime.now().year + 1;
  final List<ExpirySplit> _rows = [];

  double get _assigned => _rows.fold(0.0, (a, r) => a + r.qty);
  double get _left => widget.quantity - _assigned;

  /// SAP batches first, then last time's dates SAP does not already offer.
  List<(ExpirySplit, bool)> get _choices {
    final out = <(ExpirySplit, bool)>[for (final o in widget.options) (o.split(0), true)];
    final seen = out.map((c) => c.$1.date).toSet();
    for (final l in widget.last) {
      if (seen.add(l.date)) out.add((l.withQty(0), false));
    }
    return out;
  }

  void _choose(ExpirySplit d) {
    HapticFeedback.selectionClick();
    if (!_split) {
      Navigator.pop(context, [d.withQty(widget.quantity)]);
      return;
    }
    if (_rows.any((r) => r.date == d.date)) return;
    setState(() {
      _rows.add(d.withQty(_left > 0 ? _left : 0));
      _picker = false;
    });
  }

  void _setQty(int i, double q) => setState(() => _rows[i] = _rows[i].withQty(q < 0 ? 0 : q));

  /// Big shelves: type the number instead of tapping + forty times.
  Future<void> _typeQty(int i) async {
    final ctrl = TextEditingController(text: Fc.qty(_rows[i].qty));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_rows[i].label, textDirection: TextDirection.ltr),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: InputDecoration(suffixText: context.tr('fc_pcs')),
          onSubmitted: (t) => Navigator.pop(ctx, double.tryParse(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)), child: Text(context.tr('save'))),
        ],
      ),
    );
    if (v != null && mounted) _setQty(i, v);
  }

  @override
  Widget build(BuildContext context) {
    final pcs = context.tr('fc_pcs');
    return BottomSheetScaffold(
      title: context.tr('fc_exp_title'),
      subtitle: '${widget.productName} · ${Fc.qty(widget.quantity)} $pcs',
      icon: Icons.event_outlined,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_split ? context.tr('fc_exp_split_hint') : context.tr('fc_exp_pick'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.sm),
            if (_choices.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [for (final c in _choices) _dateChip(c.$1, sap: c.$2)],
              ),
            const SizedBox(height: AppSpacing.sm),
            if (_picker || _choices.isEmpty) _monthPicker() else _otherDateButton(),
            if (_split) ...[
              const SizedBox(height: AppSpacing.md),
              _splitRows(),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_split)
              AppButton(
                label: context.tr('fc_exp_save'),
                icon: Icons.check_rounded,
                color: Fc.accentDark,
                onPressed: _rows.isNotEmpty && _left.abs() < 0.001 && _rows.every((r) => r.qty > 0)
                    ? () => Navigator.pop(context, List<ExpirySplit>.from(_rows))
                    : null,
              )
            else
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: context.tr('fc_exp_split'),
                    icon: Icons.call_split_rounded,
                    variant: AppButtonVariant.tonal,
                    color: Fc.accentDark,
                    onPressed: widget.quantity >= 2 ? () => setState(() => _split = true) : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: context.tr('fc_exp_none'),
                    variant: AppButtonVariant.outline,
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.pop(context, <ExpirySplit>[]),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  // ─── Pieces ──────────────────────────────────────────────────

  /// A date as printed, how far it is, and where it came from.
  Widget _dateChip(ExpirySplit d, {required bool sap}) {
    final days = d.end.difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final (Color fg, Color bg) = days < 0
        ? (AppColors.error, AppColors.errorLight)
        : days <= 90
            ? (AppColors.warning, AppColors.warningLight)
            : (Fc.accentDark, Fc.soft);
    final picked = _rows.any((r) => r.date == d.date);
    return Material(
      color: picked ? fg : bg,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        borderRadius: AppRadius.borderLg,
        onTap: () => _choose(d),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 104, minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.label,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.titleMedium.copyWith(color: picked ? Colors.white : fg, fontWeight: FontWeight.w700)),
              Text(
                '${sap ? context.tr('fc_exp_sap') : context.tr('fc_exp_last')} · ${_daysLabel(days)}',
                style: AppTypography.labelSmall.copyWith(color: picked ? Colors.white : fg),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _daysLabel(int days) =>
      days < 0 ? context.tr('fc_exp_expired') : context.tr('fc_exp_days').replaceAll('{n}', '$days');

  Widget _otherDateButton() => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _picker = true),
          icon: Icon(Icons.edit_calendar_outlined, color: Fc.accentDark),
          label: Text(context.tr('fc_exp_other'),
              style: AppTypography.labelLarge.copyWith(color: Fc.accentDark, fontWeight: FontWeight.w700)),
        ),
      );

  /// Year, then month: the month tap is the choice.
  Widget _monthPicker() {
    final now = DateTime.now();
    final years = [for (var y = now.year - 1; y <= now.year + 5; y++) y];
    return FcCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('fc_exp_year'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final y in years)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  label: Text('$y'),
                  selected: _year == y,
                  showCheckmark: false,
                  selectedColor: Fc.accentDark,
                  labelStyle: AppTypography.labelLarge.copyWith(
                      color: _year == y ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _year = y),
                ),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(context.tr('fc_exp_month'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.45,
          children: [
            for (var m = 1; m <= 12; m++)
              Material(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.borderMd,
                child: InkWell(
                  borderRadius: AppRadius.borderMd,
                  onTap: () => _choose(ExpirySplit(date: '$_year-${m.toString().padLeft(2, '0')}', qty: 0)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(m.toString().padLeft(2, '0'),
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                    Text(context.tr('fc_month_$m'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _splitRows() {
    final left = _left;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: FcCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(children: [
              IconButton(
                onPressed: () => setState(() => _rows.removeAt(i)),
                icon: Icon(Icons.close_rounded, color: AppColors.textTertiary),
                tooltip: context.tr('delete'),
              ),
              Expanded(
                child: Text(_rows[i].label,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(children: [
                  _roundBtn(Icons.remove_rounded, _rows[i].qty > 0 ? () => _setQty(i, _rows[i].qty - 1) : null),
                  InkWell(
                    onTap: () => _typeQty(i),
                    borderRadius: AppRadius.borderMd,
                    child: SizedBox(
                      width: 56,
                      height: 44,
                      child: Center(
                        child: Text(Fc.qty(_rows[i].qty),
                            style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted)),
                      ),
                    ),
                  ),
                  _roundBtn(Icons.add_rounded, () => _setQty(i, _rows[i].qty + 1)),
                ]),
              ),
            ]),
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: left.abs() < 0.001 ? Fc.soft : AppColors.warningLight,
          borderRadius: AppRadius.borderLg,
        ),
        child: Text(
          left.abs() < 0.001
              ? context.tr('fc_exp_all_set').replaceAll('{n}', Fc.qty(widget.quantity))
              : left > 0
                  ? context.tr('fc_exp_left').replaceAll('{n}', Fc.qty(left))
                  : context.tr('fc_exp_over').replaceAll('{n}', Fc.qty(-left)),
          style: AppTypography.bodySmall.copyWith(
              color: left.abs() < 0.001 ? Fc.accentDark : AppColors.warning, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }

  Widget _roundBtn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: onTap == null ? AppColors.surfaceVariant : Fc.soft,
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
            child: Icon(icon, color: onTap == null ? AppColors.textTertiary : Fc.accentDark),
          ),
        ),
      );
}
