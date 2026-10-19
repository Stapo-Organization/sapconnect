import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../widgets/fc_widgets.dart';
import 'fc_count_page.dart';

/// Missing sweep: items the book says are here that no zone counted.
/// Found → count it on the shelf where it was found. Not found → a second,
/// independent zero.
class FcMissingPage extends StatefulWidget {
  final int sessionId;
  const FcMissingPage({super.key, required this.sessionId});

  @override
  State<FcMissingPage> createState() => _FcMissingPageState();
}

class _FcMissingPageState extends State<FcMissingPage> {
  final _repo = FullCountRepository();
  List<CountProduct>? _items;
  int _total = 0;
  int _found = 0;
  int _zero = 0;
  final Map<String, String> _zeroed = {}; // item_code -> line id (for undo)
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.missing(widget.sessionId);
    if (!mounted || !r.ok) return;
    setState(() {
      if (_items == null) _total = r.data!.length;
      _items = r.data;
    });
  }

  Future<void> _foundIt(CountProduct p) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FcCountPage(sessionId: widget.sessionId, presetItem: p)),
    );
    await _load();
    // Counted only if it left the missing list (the counter may have backed out).
    final still = _items?.any((i) => i.itemCode == p.itemCode) ?? true;
    if (!still && mounted) setState(() => _found++);
  }

  Future<void> _notFound(CountProduct p) async {
    final r = await _repo.markMissing(widget.sessionId, p.itemCode);
    if (!mounted) return;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    setState(() {
      _zero++;
      _zeroed[p.itemCode] = '${r.data!.id}';
      _items = _items?.where((i) => i.itemCode != p.itemCode).toList();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        persist: false,
        content: Text(context.tr('fc_marked_zero').replaceAll('{name}', p.name(AppLocalizations.isArabic))),
        action: SnackBarAction(
          label: context.tr('fc_undo'),
          onPressed: () async {
            final id = int.tryParse(_zeroed.remove(p.itemCode) ?? '');
            if (id == null) return;
            final d = await _repo.deleteLine(widget.sessionId, id);
            if (d.ok && mounted) {
              setState(() => _zero--);
              _load();
            }
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final arabic = AppLocalizations.isArabic;
    final all = _items;
    final items = all?.where((p) {
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return p.name(arabic).toLowerCase().contains(q) || p.itemCode.toLowerCase().contains(q) || (p.pieceBarcode ?? '').contains(q);
    }).toList();
    final left = all?.length ?? 0;
    final done = (_total - left).clamp(0, _total);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_missing_title')),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                FcCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(context.tr('fc_missing_explain'),
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6)),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: AppRadius.borderFull,
                          child: LinearProgressIndicator(
                            value: _total == 0 ? 1 : done / _total,
                            minHeight: 10,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(Fc.accentDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('$done / $_total', textDirection: TextDirection.ltr, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(child: _stat(context.tr('fc_found'), '$_found', Fc.accentDark, Fc.soft)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _stat(context.tr('fc_not_found_label'), '$_zero', AppColors.error, AppColors.errorLight)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _stat(context.tr('fc_left'), '$left', AppColors.textPrimary, AppColors.surfaceVariant)),
                    ]),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (v) => setState(() => _q = v.trim()),
                  decoration: InputDecoration(
                    hintText: context.tr('fc_missing_search'),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: AppRadius.borderFull, borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderFull, borderSide: BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (items!.isEmpty)
                  EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: context.tr('fc_missing_empty'),
                    subtitle: context.tr('fc_missing_empty_sub'),
                  )
                else
                  for (final p in items) _row(p, arabic),
              ],
            ),
    );
  }

  Widget _stat(String label, String v, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderLg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: AppTypography.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700))),
          Text(v, style: AppTypography.titleLarge.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _row(CountProduct p, bool arabic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FcCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProductThumb(url: p.imageUrl, size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name(arabic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 2),
                Wrap(spacing: 8, textDirection: TextDirection.ltr, children: [
                  if ((p.pieceBarcode ?? '').isNotEmpty)
                    Text(p.pieceBarcode!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  Text(p.itemCode, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: AppButton(
                label: context.tr('fc_found_count'),
                color: Fc.accentDark,
                onPressed: () => _foundIt(p),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: context.tr('fc_not_found_zero'),
                variant: AppButtonVariant.outline,
                color: AppColors.error,
                onPressed: () => _notFound(p),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
