import 'dart:async';

import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/core/permissions/app_session.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/distribution_models.dart';
import '../../data/stock_distribution_repository.dart';

/// Smart Stock Distribution (التوزيع الذكي للمخزون) — view AI redistribution
/// suggestions, filter them by source / destination / type, and re-run the
/// engine. While the engine runs we poll status and auto-refresh on completion.
class StockDistributionPage extends StatefulWidget {
  const StockDistributionPage({super.key});

  @override
  State<StockDistributionPage> createState() => _StockDistributionPageState();
}

class _StockDistributionPageState extends State<StockDistributionPage> {
  final StockDistributionRepository _repo = StockDistributionRepository();
  DistributionOverview? _data;
  bool _loading = true;
  bool _hasError = false;
  bool _running = false;
  Timer? _poll;

  // ── Filters ──
  String? _fromCode; // source warehouse (null = all)
  String? _toCode; // destination warehouse (null = all)
  String? _type; // 'central' | 'cross_dock' (null = all)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _hasError = false;
    });
    final r = await _repo.getSuggestions();
    if (!mounted) return;
    setState(() {
      _data = r.data;
      _loading = false;
      _hasError = !r.success;
      _running = r.data?.status.running ?? false;
    });
    if (_running) _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      final s = await _repo.getStatus();
      if (!mounted) return;
      if (s.success && s.status != null) {
        if (!s.status!.running) {
          _poll?.cancel();
          setState(() => _running = false);
          _load(); // engine done → refresh suggestions
        }
      }
    });
  }

  Future<void> _run() async {
    final r = await _repo.run();
    if (!mounted) return;
    final msg = r.message ?? (r.started ? context.tr('sd_run_started') : context.tr('sd_running'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (r.started) {
      setState(() => _running = true);
      _startPolling();
    }
  }

  // ─── Filter helpers ──────────────────────────────────────────
  List<DistributionLane> get _lanes => _data?.lanes ?? const [];

  List<({String code, String name})> _uniqueBy(String Function(DistributionLane) code, String Function(DistributionLane) name) {
    final map = <String, String>{};
    for (final l in _lanes) {
      map[code(l)] = name(l);
    }
    final list = map.entries.map((e) => (code: e.key, name: e.value)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<DistributionLane> get _filtered => _lanes.where((l) {
        if (_fromCode != null && l.sourceCode != _fromCode) return false;
        if (_toCode != null && l.targetCode != _toCode) return false;
        if (_type != null && l.transferType != _type) return false;
        return true;
      }).toList();

  bool get _hasActiveFilter => _fromCode != null || _toCode != null || _type != null;

  String? _nameFor(String? code, List<({String code, String name})> options) =>
      code == null ? null : options.firstWhere((o) => o.code == code, orElse: () => (code: code, name: code)).name;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('sd_title')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxl),
            children: [
              _statusCard(context),
              const SizedBox(height: AppSpacing.base),
              ..._body(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final status = _data?.status;
    final canRun = AppSession.can(Ability.stockDistributionRun);
    return AppCard(
      gradient: AppDomain.stockDistribution.gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(context.tr('sd_title'),
                    style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${intGrouped(status?.pendingCount ?? 0)} ${context.tr('sd_pending_count')}',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          Text(
            status?.lastComputedAt != null
                ? '${context.tr('sd_last_run')}: ${_fmtDate(status!.lastComputedAt!)}'
                : context.tr('sd_never_run'),
            style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (canRun) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _running ? context.tr('sd_running') : context.tr('sd_run_engine'),
              icon: _running ? null : Icons.play_circle_fill_rounded,
              loading: _running,
              onPressed: _running ? null : _run,
              color: Colors.white,
              variant: AppButtonVariant.filled,
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  List<Widget> _body(BuildContext context) {
    if (_loading) {
      return [const SkeletonCard(height: 120), const SizedBox(height: 12), const SkeletonCard(height: 120)];
    }
    if (_hasError) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.xl), child: ErrorStateWidget(onRetry: _load))];
    }
    if (_lanes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: EmptyState(icon: Icons.inventory_2_outlined, title: context.tr('sd_no_suggestions')),
        ),
      ];
    }
    final lanes = _filtered;
    return [
      _filterBar(context),
      const SizedBox(height: AppSpacing.sm),
      if (lanes.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: EmptyState(icon: Icons.filter_alt_off_rounded, title: context.tr('sd_no_match')),
        )
      else
        // دخول متتابع نابض لبطاقات الاقتراحات (موجة واحدة عند الظهور).
        for (var i = 0; i < lanes.length; i++)
          PopIn(
            delay: Duration(milliseconds: 60 * i.clamp(0, 10)),
            child: _laneCard(context, lanes[i]),
          ),
    ];
  }

  // ─── Filters bar ─────────────────────────────────────────────
  Widget _filterBar(BuildContext context) {
    final accent = AppDomain.stockDistribution.accent;
    final sources = _uniqueBy((l) => l.sourceCode, (l) => l.sourceName);
    final targets = _uniqueBy((l) => l.targetCode, (l) => l.targetName);
    const types = [null, 'central', 'cross_dock'];
    final typeLabels = [context.tr('sd_all'), context.tr('sd_central_short'), context.tr('sd_cross_dock_short')];
    return Column(
      children: [
        AppSegmentedControl(
          activeColor: accent,
          selectedIndex: types.indexOf(_type),
          onChanged: (i) => setState(() => _type = types[i]),
          items: typeLabels.map((t) => SegmentItem(t)).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _selectField(
                context,
                label: context.tr('sd_from'),
                value: _nameFor(_fromCode, sources),
                onTap: () => _pickBranch(context, context.tr('sd_from'), sources, _fromCode, (c) => setState(() => _fromCode = c)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(AppLocalizations.isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _selectField(
                context,
                label: context.tr('sd_to'),
                value: _nameFor(_toCode, targets),
                onTap: () => _pickBranch(context, context.tr('sd_to'), targets, _toCode, (c) => setState(() => _toCode = c)),
              ),
            ),
          ],
        ),
        if (_hasActiveFilter) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('${_filtered.length} ${context.tr('sd_lane')}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _fromCode = null;
                  _toCode = null;
                  _type = null;
                }),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(context.tr('sd_reset')),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _selectField(BuildContext context, {required String label, String? value, required VoidCallback onTap}) {
    final active = value != null;
    final accent = AppDomain.stockDistribution.accent;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.borderMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: active ? accent.withValues(alpha: 0.6) : AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 10)),
                    Text(value ?? context.tr('sd_all'),
                        style: AppTypography.labelMedium.copyWith(
                          color: active ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: active ? accent : AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickBranch(
    BuildContext context,
    String title,
    List<({String code, String name})> options,
    String? current,
    ValueChanged<String?> onPick,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: AppLocalizations.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadius.borderFull)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _pickTile(ctx, context.tr('sd_all'), current == null, () {
                      onPick(null);
                      Navigator.pop(ctx);
                    }),
                    ...options.map((o) => _pickTile(ctx, o.name, current == o.code, () {
                          onPick(o.code);
                          Navigator.pop(ctx);
                        })),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickTile(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final accent = AppDomain.stockDistribution.accent;
    return ListTile(
      onTap: onTap,
      title: Text(label,
          style: AppTypography.bodyMedium.copyWith(
            color: selected ? accent : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          )),
      trailing: selected ? Icon(Icons.check_rounded, color: accent, size: 20) : null,
    );
  }

  // ─── Lane card ───────────────────────────────────────────────
  Widget _laneCard(BuildContext context, DistributionLane lane) {
    final accent = AppDomain.stockDistribution.accent;
    final central = lane.transferType == 'central';
    final typeLabel = central ? context.tr('sd_central') : context.tr('sd_cross_dock');
    final typeIcon = central ? Icons.warehouse_rounded : Icons.sync_alt_rounded;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route header: [type chip]  source → target        [units]
          Row(
            children: [
              GlowIconChip(
                icon: typeIcon,
                color: accent,
                size: 36,
                iconSize: 19,
                borderRadius: AppRadius.borderMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(lane.sourceName,
                              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(AppLocalizations.isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                              size: 14, color: AppColors.textTertiary),
                        ),
                        Flexible(
                          child: Text(lane.targetName,
                              style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(typeLabel, style: AppTypography.labelSmall.copyWith(color: accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                child: Column(
                  children: [
                    Text(intGrouped(lane.totalUnits),
                        style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w800)),
                    Text(context.tr('sd_units'),
                        style: AppTypography.labelSmall.copyWith(color: accent, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: AppSpacing.lg, color: AppColors.borderLight),
          ...lane.items.map((it) => _itemRow(context, it, accent)),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, SuggestionItem it, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ProductThumb(url: it.imageUrl, size: 42, accent: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.name,
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (it.sourceStock > 0) ...[
                  const SizedBox(height: 2),
                  Text('${context.tr('sd_at_source')}: ${unitsLabel(it.sourceStock)}',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderMd),
            child: Text('${intGrouped(it.suggestedQuantity)} ${context.tr('sd_units')}',
                style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
