import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/counting_repository.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/cycle_target.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:exhibition_manager_app/features/inventory_counting/presentation/widgets/counting_line_card.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'barcode_scanner_page.dart';

/// Guided cycle-count experience: a checklist of target items with live
/// progress. Scanning ticks items off; the manager works toward 100%.
class CycleCountDetailPage extends StatefulWidget {
  final int sessionId;

  const CycleCountDetailPage({super.key, required this.sessionId});

  @override
  State<CycleCountDetailPage> createState() => _CycleCountDetailPageState();
}

class _CycleCountDetailPageState extends State<CycleCountDetailPage> {
  final CountingRepository _repo = CountingRepository();
  CycleTargetsResponse? _data;     // checklist + progress + ABC
  CountingSession? _session;       // editable entered records (lines)
  bool _loading = true;
  bool _hasError = false;
  String? _filter; // null = all, else 'A'/'B'/'C'
  int _tab = 0;    // 0 = Targets checklist, 1 = My Records

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    // Load the checklist (targets/progress) and the entered records (lines)
    // together — one reload keeps the ring, ABC counts and records consistent.
    final results = await Future.wait([
      _repo.getCycleTargets(widget.sessionId),
      _repo.getSession(widget.sessionId),
    ]);
    final targets = results[0] as ({bool success, CycleTargetsResponse? data, String? error});
    final session = results[1] as ({bool success, CountingSession? session, String? error});
    if (mounted) {
      setState(() {
        _data = targets.data;
        _session = session.session;
        _loading = false;
        _hasError = !targets.success || _data == null;
      });
    }
  }

  Future<void> _openScanner() async {
    final codes = _data?.items.map((i) => i.itemCode).toSet();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(
          countingSessionId: widget.sessionId,
          mode: ScanMode.inventoryCounting,
          isCycle: true,
          cycleTargetCodes: codes,
        ),
      ),
    );
    _load();
  }

  Future<void> _editQuantity(CountingLine line) async {
    final isArabic = AppLocalizations.isArabic;
    final controller = TextEditingController(text: line.countedQuantity.toInt().toString());
    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(line.getLocalizedName(isArabic)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge,
            decoration: InputDecoration(labelText: context.tr('quantity')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
              child: Text(context.tr('update')),
            ),
          ],
        ),
      ),
    );
    if (newQty != null && newQty >= 0) {
      await _repo.updateLine(widget.sessionId, line.id, newQty);
      await _load(); // refresh ring/by-class/records together
    }
  }

  /// Count a target without the camera: type the quantity, or mark it as not
  /// found (recorded as 0 — the zero is information for the variance report).
  Future<void> _manualCount(CycleTargetItem item) async {
    final isArabic = AppLocalizations.isArabic;
    final controller = TextEditingController();
    final qty = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.localizedName(isArabic), style: AppTypography.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Text('${ctx.tr('ic_barcode_label')}: ${item.pieceBarcode ?? "—"}   ·   ${ctx.tr('ic_sap_code_label')}: ${item.itemCode}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              const SizedBox(height: AppSpacing.base),
              Text(ctx.tr('ic_manual_count_title'), style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge,
                decoration: InputDecoration(
                  labelText: ctx.tr('quantity'),
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v.trim())),
              ),
              const SizedBox(height: AppSpacing.base),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 0.0),
                      icon: const Icon(Icons.remove_shopping_cart_outlined),
                      label: Text(ctx.tr('ic_not_found_zero')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.trim())),
                      child: Text(ctx.tr('ic_save_quantity')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (qty == null || qty < 0 || !mounted) return;
    final res = await _repo.addLine(widget.sessionId, item.itemCode, qty);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: res.success ? null : AppColors.error,
      content: Text(res.success
          ? (qty == 0 ? context.tr('ic_zero_recorded') : context.tr('product_saved').replaceAll('{name}', item.localizedName(isArabic)).replaceAll('{qty}', '${qty.toInt()}'))
          : (res.error ?? context.tr('off_list_cannot_count'))),
      duration: const Duration(seconds: 2),
    ));
    await _load();
  }

  Future<void> _deleteLine(CountingLine line) async {
    final isArabic = AppLocalizations.isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(context.tr('delete_record')),
          content: Text(context.tr('delete_record_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(context.tr('delete')),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await _repo.deleteLine(widget.sessionId, line.id);
      await _load(); // deleting the last record for an item un-ticks its target
    }
  }

  Future<void> _complete() async {
    final isArabic = AppLocalizations.isArabic;
    final p = _data!.progress;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(context.tr('complete_count')),
          content: Text(
            context.tr('ic_cycle_complete_confirm')
                .replaceAll('{counted}', '${p.countedTargets}')
                .replaceAll('{total}', '${p.totalTargets}'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: Text(context.tr('complete_count')),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    final res = await _repo.completeSession(widget.sessionId);
    if (!mounted) return;
    if (res.success) {
      if (res.gamification != null) {
        await showCelebration(context, res.gamification!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('count_completed')), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? context.tr('unexpected_error'))),
      );
    }
  }

  List<CycleTargetItem> get _visibleItems {
    final items = _data?.items ?? [];
    final filtered = _filter == null ? items : items.where((i) => i.abcClass == _filter).toList();
    // Pending first, counted sink to the bottom.
    final sorted = [...filtered]..sort((a, b) {
        if (a.counted == b.counted) return 0;
        return a.counted ? 1 : -1;
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(
          title: '${context.tr('cycle_count')} #${widget.sessionId}',
        ),
        body: _loading
            ? const SkeletonList(itemCount: 6, cardHeight: 88)
            : _hasError || _data == null
                ? ErrorStateWidget(onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppDomain.counting.accent,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverToBoxAdapter(child: _buildTabBar()),
                        if (_tab == 0) ...[
                          SliverToBoxAdapter(child: _buildAbcFilter()),
                          _buildList(),
                        ] else
                          _buildRecordsList(),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
        // Scan + complete share one bottom bar: a floating scan button used to
        // cover list rows on small phones.
        bottomNavigationBar: _buildBottom(),
      ),
    );
  }

  // ─── Hero progress card ─────────────────────────────────────
  Widget _buildHero() {
    final d = _data!;
    final p = d.progress;
    final overdue = _isOverdue(d.scheduledDate);
    final classes = ['A', 'B', 'C'].where((c) => (p.byClass[c]?.total ?? 0) > 0).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProgressRing(percent: p.percent, size: 96, stroke: 10),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d.planName != null)
                        Text(d.planName!,
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${p.countedTargets}',
                              style: AppTypography.displayMedium.copyWith(color: AppDomain.counting.accent)),
                          Text(' / ${p.totalTargets}',
                              style: AppTypography.titleMedium.copyWith(color: AppColors.textTertiary)),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(context.tr('counted_label'),
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (d.scheduledDate != null)
                        StatusBadge(
                          label: '${overdue ? context.tr('overdue_label') : context.tr('due_label')} • ${_formatDate(d.scheduledDate)}',
                          color: overdue ? AppColors.error : AppDomain.counting.accent,
                          icon: overdue ? Icons.warning_amber_rounded : Icons.event_rounded,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (classes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (int i = 0; i < classes.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(child: _classMiniBar(classes[i], p.byClass[classes[i]]!)),
                  ],
                ],
              ),
            ],
            if (p.offListScans > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(
                  label: context.tr('off_list_scans_n').replaceAll('{n}', '${p.offListScans}'),
                  color: AppColors.warning,
                  icon: Icons.report_gmailerrorred_rounded,
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
    );
  }

  Color _classColor(String cls) {
    switch (cls) {
      case 'A':
        return AppColors.error;
      case 'B':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
    }
  }

  Widget _classMiniBar(String cls, ClassProgress cp) {
    final color = _classColor(cls);
    final pct = cp.total > 0 ? (cp.counted / cp.total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderXs,
              ),
              child: Text(cls,
                  style: AppTypography.labelSmall.copyWith(
                      color: color, fontWeight: FontWeight.w700, fontSize: 10)),
            ),
            const Spacer(),
            Text('${cp.counted}/${cp.total}',
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: AppRadius.borderFull,
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── Tabs: Targets | My Records ─────────────────────────────
  Widget _buildTabBar() {
    final total = _data!.progress.totalTargets;
    final records = _session?.lines.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
      child: AppSegmentedControl(
        items: [
          SegmentItem(context.tr('cycle_targets_tab'), icon: Icons.checklist_rounded, badge: total),
          SegmentItem(context.tr('cycle_records_tab'), icon: Icons.receipt_long_rounded, badge: records),
        ],
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }

  // ─── My Records (entered lines, editable) ───────────────────
  Widget _buildRecordsList() {
    final lines = _session?.lines ?? [];
    if (lines.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: context.tr('no_records_yet'),
            subtitle: context.tr('no_records_yet_hint'),
          ),
        ),
      );
    }
    final canEdit = _data?.status == 'in_progress';
    final records = withEntryNumbers(lines);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      sliver: SliverList.builder(
        itemCount: records.length,
        itemBuilder: (context, i) {
          final r = records[i];
          return CountingLineCard(
            line: r.line,
            entryNumber: r.entry,
            canEdit: canEdit,
            onEdit: () => _editQuantity(r.line),
            onDelete: () => _deleteLine(r.line),
          );
        },
      ),
    );
  }

  // ─── ABC filter ─────────────────────────────────────────────
  Widget _buildAbcFilter() {
    final by = _data!.progress.byClass;
    final total = _data!.progress.totalTargets;
    int classTotal(String c) => by[c]?.total ?? 0;

    final items = <SegmentItem>[
      SegmentItem(context.tr('all'), badge: total),
      if (classTotal('A') > 0) SegmentItem('A', badge: classTotal('A')),
      if (classTotal('B') > 0) SegmentItem('B', badge: classTotal('B')),
      if (classTotal('C') > 0) SegmentItem('C', badge: classTotal('C')),
    ];
    // Map filter value to index
    final values = <String?>[null, if (classTotal('A') > 0) 'A', if (classTotal('B') > 0) 'B', if (classTotal('C') > 0) 'C'];
    final selectedIndex = values.indexOf(_filter).clamp(0, values.length - 1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
      child: AppSegmentedControl(
        items: items,
        selectedIndex: selectedIndex,
        onChanged: (i) => setState(() => _filter = values[i]),
      ),
    );
  }

  // ─── Items list ─────────────────────────────────────────────
  Widget _buildList() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxl),
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: context.tr('no_targets'),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) => _TargetTile(
          item: items[i],
          onTap: (_data?.status == 'in_progress') ? () => _manualCount(items[i]) : null,
        ),
      ),
    );
  }

  // ─── Bottom complete bar ────────────────────────────────────
  Widget? _buildBottom() {
    final d = _data;
    if (d == null || d.status != 'in_progress') return null;
    final p = d.progress;
    // Enable once any record exists (backend requires ≥1 line). Gating on
    // countedTargets alone could leave the button stuck when only off-list
    // legacy records are present.
    final canComplete = (_session?.lines.isNotEmpty ?? false) || p.countedTargets > 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: AppButton(
                  label: context.tr('scan_to_count'),
                  onPressed: _openScanner,
                  icon: Icons.qr_code_scanner_rounded,
                  color: AppDomain.counting.accentDark,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: '${context.tr('complete_count')} ${p.countedTargets}/${p.totalTargets}',
                  onPressed: canComplete ? _complete : null,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  variant: AppButtonVariant.tonal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOverdue(String? date) {
    if (date == null) return false;
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Format an ISO date/datetime to a clean `yyyy-MM-dd` (the API may return a
  /// full timestamp; never show the raw ISO string to the user).
  String _formatDate(String? date) {
    if (date == null) return '';
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

// ─── Target item tile ─────────────────────────────────────────
class _TargetTile extends StatelessWidget {
  final CycleTargetItem item;
  final VoidCallback? onTap;
  const _TargetTile({required this.item, this.onTap});

  Color get _classColor {
    switch (item.abcClass) {
      case 'A':
        return AppColors.error;
      case 'B':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final done = item.counted;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderLg,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: done ? AppColors.successLight.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight),
      ),
      child: Row(
        children: [
          // image
          ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: CachedNetworkImage(
              imageUrl: item.imageUrl ?? '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (c, u) => Shimmer.fromColors(
                baseColor: AppColors.surfaceVariant,
                highlightColor: AppColors.surface,
                child: Container(width: 50, height: 50, color: Colors.white),
              ),
              errorWidget: (c, u, e) => Container(
                width: 50,
                height: 50,
                color: AppColors.surfaceVariant,
                child: Icon(Icons.image_not_supported_rounded, size: 22, color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // name + code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.localizedName(isArabic),
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _classColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.borderXs,
                      ),
                      child: Text(item.abcClass ?? '-',
                          style: AppTypography.labelSmall.copyWith(
                              color: _classColor, fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    // Barcode and SAP code wrap onto two lines when narrow;
                    // neither may be cut — the counter identifies items by them.
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        textDirection: TextDirection.ltr,
                        children: [
                          if (item.pieceBarcode != null && item.pieceBarcode!.isNotEmpty)
                            Text(item.pieceBarcode!,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                textDirection: TextDirection.ltr),
                          Text(item.itemCode,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                              textDirection: TextDirection.ltr),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // status / qty
          if (done)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                const SizedBox(height: 2),
                Text('${item.countedQuantity.toInt()}',
                    style: AppTypography.labelMedium.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            )
          else
            Icon(Icons.radio_button_unchecked_rounded,
                color: AppColors.textTertiary.withValues(alpha: 0.6), size: 24),
        ],
      ),
      ),
    );
  }
}
