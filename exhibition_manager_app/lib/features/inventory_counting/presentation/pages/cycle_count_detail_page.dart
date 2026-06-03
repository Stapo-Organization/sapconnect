import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
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
  CycleTargetsResponse? _data;
  bool _loading = true;
  bool _hasError = false;
  String? _filter; // null = all, else 'A'/'B'/'C'

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
    final res = await _repo.getCycleTargets(widget.sessionId);
    if (mounted) {
      setState(() {
        _data = res.data;
        _loading = false;
        _hasError = !res.success;
      });
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(
          countingSessionId: widget.sessionId,
          mode: ScanMode.inventoryCounting,
        ),
      ),
    );
    _load();
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
            isArabic
                ? 'تم عدّ ${p.countedTargets} من ${p.totalTargets} صنف. سيتم إكمال المهمة الآن.'
                : 'Counted ${p.countedTargets} of ${p.totalTargets}. The task will be completed now.',
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
                    color: AppColors.primary,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverToBoxAdapter(child: _buildAbcFilter()),
                        _buildList(),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
        floatingActionButton: (_data?.status == 'in_progress')
            ? FloatingActionButton.extended(
                onPressed: _openScanner,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryDark,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(context.tr('scan_to_count'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            : null,
        bottomNavigationBar: _buildBottom(),
      ),
    );
  }

  // ─── Hero progress card ─────────────────────────────────────
  Widget _buildHero() {
    final d = _data!;
    final p = d.progress;
    final overdue = _isOverdue(d.scheduledDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            ProgressRing(percent: p.percent, size: 104, stroke: 11),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.planName != null)
                    Text(d.planName!,
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('${p.countedTargets}',
                          style: AppTypography.displayMedium.copyWith(color: AppColors.primary)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(' / ${p.totalTargets}',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.textTertiary)),
                      ),
                    ],
                  ),
                  Text('${p.remaining} ${context.tr('remaining_items')}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  if (d.scheduledDate != null)
                    StatusBadge(
                      label: overdue
                          ? context.tr('overdue_label')
                          : '${context.tr('due_label')} • ${d.scheduledDate}',
                      color: overdue ? AppColors.error : AppColors.primary,
                      icon: overdue ? Icons.warning_amber_rounded : Icons.event_rounded,
                    ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
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
        itemBuilder: (context, i) => _TargetTile(item: items[i]),
      ),
    );
  }

  // ─── Bottom complete bar ────────────────────────────────────
  Widget? _buildBottom() {
    final d = _data;
    if (d == null || d.status != 'in_progress') return null;
    final p = d.progress;
    final canComplete = p.countedTargets > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base),
        child: AppButton(
          label: '${context.tr('complete_count')} (${p.countedTargets}/${p.totalTargets})',
          onPressed: canComplete ? _complete : null,
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
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
}

// ─── Target item tile ─────────────────────────────────────────
class _TargetTile extends StatelessWidget {
  final CycleTargetItem item;
  const _TargetTile({required this.item});

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
    return Container(
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
                child: const Icon(Icons.image_not_supported, size: 22, color: AppColors.textTertiary),
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
                  maxLines: 2,
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
                              color: _classColor, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(item.itemCode,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
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
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
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
    );
  }
}
