import 'dart:async';

import 'package:flutter/material.dart';

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
/// suggestions and re-run the engine. While the engine runs we poll status and
/// auto-refresh the list when it completes.
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

  @override
  Widget build(BuildContext context) {
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
    final lanes = _data?.lanes ?? [];
    if (lanes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: EmptyState(icon: Icons.inventory_2_outlined, title: context.tr('sd_no_suggestions')),
        ),
      ];
    }
    return lanes.map((l) => _laneCard(context, l)).toList();
  }

  Widget _laneCard(BuildContext context, DistributionLane lane) {
    final accent = AppDomain.stockDistribution.accent;
    final typeLabel = lane.transferType == 'central' ? context.tr('sd_central') : context.tr('sd_cross_dock');
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(lane.sourceName, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_back_rounded, size: 14)),
                        Flexible(child: Text(lane.targetName, style: AppTypography.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    Text(typeLabel, style: AppTypography.labelSmall.copyWith(color: accent)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                child: Text('${intGrouped(lane.totalUnits)} ${context.tr('sd_units')}',
                    style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          ...lane.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(it.name, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${intGrouped(it.suggestedQuantity)} ${context.tr('sd_units')}',
                        style: AppTypography.labelMedium.copyWith(color: accent, fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
