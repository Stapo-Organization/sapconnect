import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../widgets/fc_kind_picture.dart';
import '../widgets/fc_widgets.dart';

/// The showroom map: display units (gondolas, walls, end caps, cashier,
/// back room) and their shelves, each with a printed label. A map only —
/// stock stays item × showroom in SAP.
class FcMapPage extends StatefulWidget {
  final String warehouseCode;
  const FcMapPage({super.key, required this.warehouseCode});

  @override
  State<FcMapPage> createState() => _FcMapPageState();
}

class _FcMapPageState extends State<FcMapPage> {
  static const kinds = ['gondola', 'wall', 'endcap', 'cashier', 'backroom', 'other'];
  final _repo = FullCountRepository();
  StoreMap? _map;
  String _filter = 'floor'; // floor | backroom | cashier

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.map(widget.warehouseCode);
    if (!mounted) return;
    if (r.ok) setState(() => _map = r.data);
  }

  bool _inFilter(StoreUnit u) {
    switch (_filter) {
      case 'backroom':
        return u.kind == 'backroom';
      case 'cashier':
        return u.kind == 'cashier';
      default:
        return u.kind != 'backroom' && u.kind != 'cashier';
    }
  }

  Future<void> _editUnit({StoreUnit? unit}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Scrollable so «حفظ» stays reachable above the keyboard on small phones.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: _UnitSheet(repo: _repo, wh: widget.warehouseCode, unit: unit, defaultKind: _filter == 'floor' ? 'gondola' : _filter),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _print() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BottomSheetScaffold(
        title: context.tr('fc_print_title'),
        icon: Icons.print_outlined,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.grid_on_rounded),
            title: Text(context.tr('fc_print_a4')),
            subtitle: Text(context.tr('fc_print_a4_sub')),
            onTap: () => Navigator.pop(ctx, 'a4'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(context.tr('fc_print_thermal')),
            subtitle: Text(context.tr('fc_print_thermal_sub')),
            onTap: () => Navigator.pop(ctx, 'thermal'),
          ),
        ]),
      ),
    );
    if (format == null) return;
    final r = await _repo.labelsLink(widget.warehouseCode, format: format);
    if (!mounted) return;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    await launchUrl(Uri.parse(r.data!), mode: LaunchMode.externalApplication);
  }

  Future<void> _verify() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _VerifyLabelsPage(repo: _repo, wh: widget.warehouseCode)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final m = _map;
    final units = m?.units.where(_inFilter).toList() ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_map_title')),
      body: m == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: Fc.accent,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  FcCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: _stat(context.tr('fc_units'), '${m.units.length}')),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _stat(context.tr('fc_shelves'), '${m.shelves}')),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _stat(context.tr('fc_labels_stuck'), '${m.labeled} / ${m.shelves}', accent: true)),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Text(context.tr('fc_map_explain'),
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6)),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: AppSpacing.sm, children: [
                    for (final f in ['floor', 'backroom', 'cashier'])
                      ChoiceChip(
                        label: Text(context.tr('fc_area_$f')),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppColors.textPrimary,
                        labelStyle: AppTypography.labelLarge.copyWith(
                            color: _filter == f ? AppColors.surface : AppColors.textPrimary, fontWeight: FontWeight.w700),
                        showCheckmark: false,
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  for (final u in units) _unitRow(u),
                  OutlinedButton.icon(
                    onPressed: () => _editUnit(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.tr('fc_add_unit')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Fc.accentDark,
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: Fc.accent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _legend(),
                ],
              ),
            ),
      bottomNavigationBar: m == null || m.units.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: AppButton(label: context.tr('fc_print_labels'), icon: Icons.print_outlined, color: Fc.accentDark, onPressed: _print),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: context.tr('fc_check_labels'),
                      icon: Icons.qr_code_scanner_rounded,
                      color: Fc.accentDark,
                      variant: AppButtonVariant.tonal,
                      onPressed: _verify,
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _stat(String label, String value, {bool accent = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: accent ? Fc.soft : AppColors.surfaceVariant, borderRadius: AppRadius.borderLg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: AppTypography.labelSmall.copyWith(color: accent ? Fc.accentDark : AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                textDirection: TextDirection.ltr,
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, color: accent ? Fc.accentDark : AppColors.textPrimary)),
          ),
        ]),
      );

  Widget _unitRow(StoreUnit u) {
    final all = u.labeled == u.shelves.length && u.shelves.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl, side: BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: AppRadius.borderXl,
          onTap: () => _editUnit(unit: u),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              UnitBadge(code: u.unitCode, kind: u.kind, size: 54),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${Fc.kindLabel(context, u.kind)}${u.name != null ? ' · ${u.name}' : ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${context.tr('fc_n_shelves').replaceAll('{n}', '${u.shelves.length}')} · ${u.shelves.first.code} … ${u.shelves.last.code}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ]),
              ),
              Text('${u.labeled}/${u.shelves.length}',
                  textDirection: TextDirection.ltr,
                  style: AppTypography.labelLarge.copyWith(
                      color: all ? Fc.accentDark : AppColors.warning, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _legend() => const FcCodeGuide();
}

class _UnitSheet extends StatefulWidget {
  final FullCountRepository repo;
  final String wh;
  final StoreUnit? unit;
  final String defaultKind;
  const _UnitSheet({required this.repo, required this.wh, this.unit, required this.defaultKind});
  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  late String _kind = widget.unit?.kind ?? widget.defaultKind;
  late final _name = TextEditingController(text: widget.unit?.name ?? '');
  late int _shelves = widget.unit?.shelves.length ?? 5;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final name = _name.text.trim().isEmpty ? null : _name.text.trim();
    final r = widget.unit == null
        ? await widget.repo.addUnit(widget.wh, kind: _kind, name: name, shelves: _shelves)
        : await widget.repo.updateUnit(widget.wh, widget.unit!.unitCode, name: name, shelves: _shelves);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final r = await widget.repo.deleteUnit(widget.wh, widget.unit!.unitCode);
    if (!mounted) return;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.unit != null;
    return BottomSheetScaffold(
      title: editing ? widget.unit!.unitCode : context.tr('fc_add_unit'),
      icon: Icons.shelves,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!editing) ...[
            Text(context.tr('fc_unit_kind'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            // Pick the place by its picture, not by a term.
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - AppSpacing.sm * 2) / 3;
              return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final k in _FcMapPageState.kinds)
                  SizedBox(
                    width: w,
                    child: Material(
                      color: _kind == k ? Fc.soft : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderLg,
                        side: BorderSide(color: _kind == k ? Fc.accentDark : AppColors.border, width: _kind == k ? 2 : 1),
                      ),
                      child: InkWell(
                        borderRadius: AppRadius.borderLg,
                        onTap: () => setState(() => _kind = k),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(children: [
                            FcKindPicture(kind: k, width: w - AppSpacing.sm * 2 - 8),
                            const SizedBox(height: 4),
                            Text('${fcKindLetters[k]} · ${Fc.kindLabel(context, k)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: context.tr('fc_unit_name'),
              hintText: context.tr('fc_unit_name_hint'),
              border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: Text(context.tr('fc_shelf_count'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700))),
            IconButton.filled(
              onPressed: _shelves > 1 ? () => setState(() => _shelves--) : null,
              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceVariant, foregroundColor: AppColors.textPrimary),
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text('$_shelves', textAlign: TextAlign.center, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton.filled(
              onPressed: _shelves < 12 ? () => setState(() => _shelves++) : null,
              style: IconButton.styleFrom(backgroundColor: Fc.accentDark),
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          Text(context.tr('fc_shelf_count_hint'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.base),
          AppButton(label: context.tr('save'), icon: Icons.check_rounded, color: Fc.accentDark, loading: _busy, onPressed: _save),
          if (editing) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(context.tr('fc_delete_unit')),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Scan each stuck label once: confirms it is in place and readable.
class _VerifyLabelsPage extends StatefulWidget {
  final FullCountRepository repo;
  final String wh;
  const _VerifyLabelsPage({required this.repo, required this.wh});
  @override
  State<_VerifyLabelsPage> createState() => _VerifyLabelsPageState();
}

class _VerifyLabelsPageState extends State<_VerifyLabelsPage> {
  final _camera = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final List<String> _ok = [];
  bool _busy = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || _busy) return;
    setState(() => _busy = true);
    final r = await widget.repo.verifyLabel(widget.wh, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      HapticFeedback.mediumImpact();
      if (!_ok.contains(r.data)) setState(() => _ok.insert(0, r.data!));
    } else {
      HapticFeedback.heavyImpact();
      Fc.toast(context, r.error ?? '', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_check_labels')),
      body: Column(children: [
        SizedBox(height: context.byWidth(regular: 320.0, compact: 260.0), child: MobileScanner(controller: _camera, onDetect: _onDetect)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              Text(context.tr('fc_check_labels_hint'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                for (final c in _ok)
                  Chip(
                    avatar: Icon(Icons.check_circle_rounded, color: Fc.accentDark, size: 18),
                    label: Text(c, textDirection: TextDirection.ltr),
                    backgroundColor: Fc.soft,
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
