import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../widgets/fc_expiry_sheet.dart';
import '../widgets/fc_widgets.dart';

/// The counting screen. Round 1: scan a shelf label, then each product on it
/// once and type its quantity (blind — the book quantity is never shown).
/// Rounds 2/3 (recount) and «found» from the missing sweep reuse it with a
/// preset item. Round 1 also asks the expiry printed on the packs.
class FcCountPage extends StatefulWidget {
  final int sessionId;
  final int round;
  final String? unitCode;
  final CountProduct? presetItem;
  final String? presetLocation;
  /// Recount: where round 1 found the item — the close check lists the ones not visited.
  final List<String> recountLocations;

  const FcCountPage({
    super.key,
    required this.sessionId,
    this.round = 1,
    this.unitCode,
    this.presetItem,
    this.presetLocation,
    this.recountLocations = const [],
  });

  @override
  State<FcCountPage> createState() => _FcCountPageState();
}

class _UndoLine {
  final CountLine line;
  final DateTime until;
  /// A recount line stays editable until the counter closes the item.
  final bool sticky;
  _UndoLine(this.line, {this.sticky = false}) : until = DateTime.now().add(const Duration(seconds: 10));
  bool get canUndo => sticky || DateTime.now().isBefore(until);
}

class _FcCountPageState extends State<FcCountPage> {
  final _repo = FullCountRepository();
  final _camera = MobileScannerController(detectionSpeed: DetectionSpeed.normal);

  ScanLocation? _location;
  CountProduct? _product;
  bool _scannedCarton = false;
  double? _packSize;
  String _qty = '';
  CartonEntry? _carton;
  List<ExpiryOption> _expiryOptions = const [];
  /// What this counter read last time per item: the next scan is one tap.
  final Map<String, List<ExpirySplit>> _lastExpiry = {};
  bool _busy = false;
  bool _torch = false;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_UndoLine> _recent = [];
  Timer? _ticker;

  /// The unit this counter holds; moving to another unit's shelf closes it first.
  late String? _unitCode = widget.unitCode;

  bool get _isRecount => widget.round >= 2;
  /// A recount from the queue: its lines stay open (and editable) until closed.
  bool get _openRecount => _isRecount && widget.presetItem != null;
  bool get _needsShelf => widget.round == 1 && _location == null;

  @override
  void initState() {
    super.initState();
    if (widget.presetLocation != null) {
      _location = ScanLocation(code: widget.presetLocation!, unitCode: widget.presetLocation!.split('-').first, shelfNo: 0);
    }
    if (widget.presetItem != null && !_needsShelf) {
      _product = widget.presetItem;
    }
    if (widget.presetItem != null && widget.round == 1) _loadExpiryOptions(widget.presetItem!.itemCode);
    if (_openRecount) _loadOpenLines();
    // Keeps the «undo» buttons honest (they expire after 10 s).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _recent.any((r) => r.canUndo)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera.dispose();
    super.dispose();
  }

  /// Back to a recount left half-way: what this counter already recorded, editable.
  Future<void> _loadOpenLines() async {
    final r = await _repo.myLines(widget.sessionId, item: widget.presetItem!.itemCode, round: widget.round);
    if (!mounted || !r.ok) return;
    setState(() {
      _recent
        ..clear()
        ..addAll(r.data!.map((l) => _UndoLine(l, sticky: true)));
    });
  }

  /// Closing the recount: every place covered? Then the lines count.
  Future<void> _closeRecount() async {
    final total = _recent.fold<double>(0, (a, r) => a + r.line.quantity);
    final visited = _recent.map((r) => r.line.locationCode).whereType<String>().toSet();
    final notVisited = widget.recountLocations.where((l) => !visited.contains(l)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_close_recount_q')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('fc_close_recount_sum').replaceAll('{q}', Fc.qty(total)).replaceAll('{n}', '${_recent.length}')),
          if (notVisited.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(context.tr('fc_close_recount_missing'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
            Text(notVisited.join('  ·  '), textDirection: TextDirection.ltr, style: AppTypography.mono),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('fc_keep_counting'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('fc_close_recount_go'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await _repo.closeRecount(widget.sessionId, widget.presetItem!.itemCode);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    Navigator.pop(context, true);
  }

  /// A shelf of another unit while holding one: close mine and move, or stay.
  Future<bool> _moveToUnit(ScanLocation loc) async {
    final from = _unitCode!;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_other_unit_q').replaceAll('{o}', loc.unitCode)),
        content: Text(context.tr('fc_other_unit_body').replaceAll('{u}', from).replaceAll('{o}', loc.unitCode)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('fc_stay_in_unit').replaceAll('{u}', from))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('fc_move_to_unit').replaceAll('{u}', from).replaceAll('{o}', loc.unitCode)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return false;
    final r = await _repo.unitAction(widget.sessionId, loc.unitCode, 'claim', closePrevious: true);
    if (!mounted) return false;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return false;
    }
    setState(() {
      _unitCode = loc.unitCode;
      _recent.clear();
    });
    Fc.toast(context, context.tr('fc_moved_unit').replaceAll('{u}', from).replaceAll('{o}', loc.unitCode));
    return true;
  }

  /// «Found» from the missing sweep starts without a product scan: fetch SAP's dates for it.
  Future<void> _loadExpiryOptions(String itemCode) async {
    final r = await _repo.resolve(widget.sessionId, itemCode);
    if (mounted && r.ok && r.data!.product?.itemCode == itemCode) {
      setState(() => _expiryOptions = r.data!.expiryOptions);
    }
  }

  // ─── Scanning ────────────────────────────────────────────────
  void _onDetect(BarcodeCapture cap) {
    final code = cap.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty || _busy) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _lastCode = code;
    _lastAt = now;
    _handleCode(code);
  }

  Future<void> _handleCode(String code) async {
    setState(() => _busy = true);
    final r = await _repo.resolve(widget.sessionId, code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      HapticFeedback.heavyImpact();
      Fc.toast(context, r.error ?? context.tr('fc_not_found'), error: true);
      return;
    }
    final res = r.data!;
    if (res.isLocation) {
      HapticFeedback.mediumImpact();
      if (_unitCode != null && widget.round == 1 && res.location!.unitCode != _unitCode) {
        // Counting another unit's shelf would leave this one open behind.
        if (!await _moveToUnit(res.location!) || !mounted) return;
      }
      setState(() => _location = res.location);
      if (widget.presetItem != null && _product == null) {
        setState(() => _product = widget.presetItem);
      }
      return;
    }
    if (_needsShelf) {
      HapticFeedback.heavyImpact();
      Fc.toast(context, context.tr('fc_scan_shelf_first'), error: true);
      return;
    }
    if (widget.presetItem != null && res.product!.itemCode != widget.presetItem!.itemCode) {
      HapticFeedback.heavyImpact();
      Fc.toast(context, context.tr('fc_wrong_item'), error: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _product = res.product;
      _scannedCarton = res.isCarton;
      _packSize = res.packSize;
      _expiryOptions = res.expiryOptions;
      _qty = '';
      _carton = null;
    });
    if (res.isCarton) _openCarton();
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_manual_title')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: context.tr('fc_manual_hint')),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(context.tr('fc_search'))),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) _handleCode(code);
  }

  Future<void> _openCarton() async {
    final p = _product;
    if (p == null) return;
    final res = await showCartonSheet(context,
        productName: p.name(AppLocalizations.isArabic), packSize: _packSize, scannedCarton: _scannedCarton);
    if (!mounted || res == null) return;
    setState(() {
      _carton = res;
      _qty = Fc.qty(res.total);
    });
    _save();
  }

  // ─── Saving ──────────────────────────────────────────────────
  Future<void> _save() async {
    final p = _product;
    if (p == null || _busy) return;
    if (_carton == null && _qty.isEmpty) {
      Fc.toast(context, context.tr('fc_enter_qty'), error: true);
      return;
    }
    final total = _carton?.total ?? double.tryParse(_qty) ?? 0;
    // The recount rounds only settle quantities; dates are read once, in round 1.
    List<ExpirySplit>? expiries;
    if (widget.round == 1 && total > 0) {
      expiries = await showExpirySheet(
        context,
        productName: p.name(AppLocalizations.isArabic),
        quantity: total,
        options: _expiryOptions,
        last: _lastExpiry[p.itemCode] ?? const [],
      );
      if (!mounted || expiries == null) return; // dismissed: the product stays open
    }
    setState(() => _busy = true);
    final r = await _repo.count(
      widget.sessionId,
      itemCode: p.itemCode,
      locationCode: _location?.code,
      round: widget.round,
      quantity: _carton == null ? double.tryParse(_qty) : null,
      cartons: _carton?.cartons,
      packSize: _carton?.packSize,
      loose: _carton?.loose,
      expiries: expiries,
      unitCode: widget.round == 1 ? _unitCode : null,
      keepOpen: _openRecount,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      HapticFeedback.heavyImpact();
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    HapticFeedback.lightImpact();
    if (expiries != null && expiries.isNotEmpty) _lastExpiry[p.itemCode] = expiries;
    if (widget.presetItem != null && widget.round == 1) {
      // «Found» from the missing sweep: one line, then back to the list.
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _recent.insert(0, _UndoLine(r.data!, sticky: _openRecount));
      if (_recent.length > 8 && !_openRecount) _recent.removeLast();
      _product = _isRecount ? widget.presetItem : null; // recount: may be on more shelves
      _qty = '';
      _carton = null;
      _scannedCarton = false;
      _expiryOptions = const [];
    });
  }

  Future<void> _undo(_UndoLine u) async {
    final r = await _repo.deleteLine(widget.sessionId, u.line.id);
    if (!mounted) return;
    if (r.ok) {
      setState(() => _recent.remove(u));
      Fc.toast(context, context.tr('fc_undone'));
    } else {
      Fc.toast(context, r.error ?? '', error: true);
    }
  }

  void _digit(String d) {
    if (_product == null) return;
    if (_qty.length >= 6) return;
    setState(() {
      _carton = null;
      _qty = (_qty == '0' ? '' : _qty) + d;
    });
  }

  void _back() {
    if (_qty.isEmpty) return;
    setState(() {
      _carton = null;
      _qty = _qty.substring(0, _qty.length - 1);
    });
  }

  // ─── UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final camH = _product == null
        ? context.byWidth(regular: 300.0, compact: 240.0, tiny: 200.0)
        // While a product is open the camera shrinks to a strip so the whole
        // keypad fits a 640dp phone above the pinned save bar.
        : context.byWidth(regular: 150.0, compact: _isRecount ? 64.0 : 84.0, tiny: _isRecount ? 60.0 : 72.0);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _actionBar(),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: camH + MediaQuery.paddingOf(context).top,
            child: _cameraArea(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isRecount) _recountBanner(),
                  _product == null ? _prompt() : _productPanel(),
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.base),
                    FcSectionTitle(_location != null
                        ? context.tr('fc_recent_on').replaceAll('{s}', _location!.code)
                        : context.tr('fc_recent')),
                    _recentList(),
                  ],
                  if (_isRecount && _recent.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.base),
                    AppButton(
                      label: context.tr('fc_done_item'),
                      icon: Icons.check_rounded,
                      color: Fc.accentDark,
                      variant: AppButtonVariant.tonal,
                      loading: _busy,
                      onPressed: _openRecount ? _closeRecount : () => Navigator.pop(context, true),
                    ),
                    if (_openRecount)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(context.tr('fc_recount_open_hint'),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraArea() {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: const Color(0xFF1B1D24), child: MobileScanner(controller: _camera, onDetect: _onDetect)),
        if (_product == null || !context.isCompact)
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: top + 30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: context.screenWidth * 0.62,
              height: _product == null ? 110 : 70,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF34D399), width: 3),
                borderRadius: AppRadius.borderLg,
              ),
            ),
          ),
        ),
        Positioned(
          top: top + AppSpacing.sm,
          left: AppSpacing.base,
          right: AppSpacing.base,
          child: Row(
            children: [
              _glassBtn(Icons.arrow_back_rounded, () => Navigator.pop(context), context.tr('back')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Center(child: _shelfChip())),
              const SizedBox(width: AppSpacing.sm),
              _glassBtn(Icons.keyboard_alt_outlined, _manualEntry, context.tr('fc_manual_title')),
              const SizedBox(width: AppSpacing.sm),
              _glassBtn(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, () {
                _camera.toggleTorch();
                setState(() => _torch = !_torch);
              }, context.tr('fc_torch')),
            ],
          ),
        ),
        if (_busy)
          const Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))),
          ),
      ],
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 22)),
          ),
        ),
      );

  Widget _shelfChip() {
    final has = _location != null;
    if (!has && _isRecount) {
      // A recount covers every place the item sits; a shelf label is optional.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: AppRadius.borderFull),
        child: Text(widget.round == 3 ? context.tr('fc_round3') : context.tr('fc_round2'),
            style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: has ? Fc.accentDark : AppColors.warning.withValues(alpha: 0.8),
        borderRadius: AppRadius.borderFull,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(has ? Icons.shelves : Icons.qr_code_2_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            has ? _location!.code : context.tr('fc_no_shelf'),
            textDirection: has ? TextDirection.ltr : null,
            style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }

  Widget _recountBanner() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: FcCard(
          color: AppColors.warningLight,
          borderColor: AppColors.warning.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Icon(Icons.visibility_off_outlined, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.round == 3 ? context.tr('fc_round3_banner') : context.tr('fc_round2_banner'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, height: 1.5),
              ),
            ),
          ]),
        ),
      );

  Widget _prompt() {
    final shelf = _needsShelf;
    return FcCard(
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: shelf ? AppColors.warningLight : Fc.soft, borderRadius: AppRadius.borderLg),
          child: Icon(shelf ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
              color: shelf ? AppColors.warning : Fc.accentDark, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shelf ? context.tr('fc_prompt_shelf') : context.tr('fc_prompt_product'),
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(shelf ? context.tr('fc_prompt_shelf_hint') : context.tr('fc_prompt_product_hint'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _productPanel() {
    final p = _product!;
    final arabic = AppLocalizations.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProductThumb(url: p.imageUrl, size: context.byWidth(regular: 64.0, compact: 48.0)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_scannedCarton)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: AppRadius.borderFull),
                      child: Text(context.tr('fc_carton_barcode'),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Text(p.name(arabic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 2, textDirection: TextDirection.ltr, children: [
                  if ((p.pieceBarcode ?? '').isNotEmpty)
                    Text(p.pieceBarcode!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  Text(p.itemCode, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        FcCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    _location != null
                        ? context.tr('fc_qty_on_shelf').replaceAll('{s}', _location!.code)
                        : context.tr('fc_qty_all_places'),
                    style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Text(context.tr('fc_blind'), style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_qty.isEmpty ? '0' : _qty,
                        style: (context.isCompact ? AppTypography.headlineLarge : AppTypography.displayMedium).copyWith(
                            fontWeight: FontWeight.w700,
                            color: _qty.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Text(context.tr('fc_pcs'), style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_carton != null)
                Text('${Fc.qty(_carton!.cartons)} × ${Fc.qty(_carton!.packSize)} + ${Fc.qty(_carton!.loose)}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: AppTypography.bodySmall.copyWith(color: Fc.accentDark)),
              CountKeypad(onDigit: _digit, onBackspace: _back, onCarton: _openCarton),
            ],
          ),
        ),
      ],
    );
  }

  /// Pinned under the scroll so «حفظ» is always reachable on small phones.
  Widget? _actionBar() {
    if (_product == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          if (!_isRecount)
            Expanded(
              flex: 2,
              child: AppButton(
                label: context.tr('fc_not_here'),
                variant: AppButtonVariant.outline,
                color: AppColors.textSecondary,
                onPressed: () => setState(() {
                  _product = null;
                  _qty = '';
                  _carton = null;
                }),
              ),
            ),
          if (!_isRecount) const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: AppButton(
              // Round 1 asks the pack's date next: say so on the button.
              label: context.tr(widget.round == 1 ? 'fc_save_to_date' : 'fc_save_next'),
              icon: widget.round == 1 ? Icons.event_outlined : Icons.check_rounded,
              color: Fc.accentDark,
              loading: _busy,
              onPressed: (_qty.isNotEmpty || _carton != null) ? _save : null,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _recentList() {
    return FcCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < _recent.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_recent[i].line.name(AppLocalizations.isArabic),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMedium),
                    if (_openRecount)
                      Text(_recent[i].line.locationCode ?? context.tr('fc_no_shelf'),
                          textDirection: TextDirection.ltr,
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                    if (_recent[i].line.expiries != null)
                      Text(
                        _recent[i].line.expiries!.isEmpty
                            ? context.tr('fc_exp_none')
                            : _recent[i].line.expiries!.map((e) => '${e.label} × ${Fc.qty(e.qty)}').join('  ·  '),
                        textDirection: _recent[i].line.expiries!.isEmpty ? null : TextDirection.ltr,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(Fc.qty(_recent[i].line.quantity),
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                if (_recent[i].canUndo) ...[
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(onPressed: () => _undo(_recent[i]), child: Text(context.tr('fc_undo'))),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
