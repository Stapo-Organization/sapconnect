import 'dart:async';
import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../widgets/fc_widgets.dart';
import 'fc_unit_page.dart';
import 'fc_recount_page.dart';
import 'fc_missing_page.dart';
import 'fc_result_page.dart';

/// The live board of a full count — the hub for the supervisor and the team:
/// progress, the five stages of the day, what needs attention, every unit
/// and who is counting it.
class FcBoardPage extends StatefulWidget {
  final int sessionId;
  const FcBoardPage({super.key, required this.sessionId});

  @override
  State<FcBoardPage> createState() => _FcBoardPageState();
}

class _FcBoardPageState extends State<FcBoardPage> {
  final _repo = FullCountRepository();
  FullCountBoard? _b;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final r = await _repo.board(widget.sessionId);
    if (!mounted) return;
    setState(() {
      if (r.ok) {
        _b = r.data;
        _error = null;
      } else if (!silent || _b == null) {
        _error = r.error;
      }
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load(silent: true);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_cancel_q')),
        content: Text(context.tr('fc_cancel_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('fc_cancel_keep'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('fc_cancel')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await _repo.cancel(widget.sessionId);
    if (!mounted) return;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    _poll?.cancel();
    Fc.toast(context, context.tr('fc_cancelled'));
    Navigator.pop(context);
  }

  /// 0 prep · 1 counting · 2 recount · 3 missing · 4 approval
  int _stage(FullCountBoard b) {
    if (b.session.status == 'completed') return 5;
    if (b.unitsTotal == 0 || b.unitsDone < b.unitsTotal) return 1;
    if (b.recount + b.supervisor > 0) return 2;
    if (b.missing > 0) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(
        title: context.tr('fc_board_title'),
        actions: [
          if (_b != null && _b!.session.status != 'completed' && _b!.canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) => v == 'cancel' ? _cancel() : null,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(children: [
                    Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(context.tr('fc_cancel'), style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: _b == null
          ? (_error != null
              ? ErrorStateWidget(onRetry: _load, subtitle: _error)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              color: Fc.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xxl),
                children: [
                  _hero(_b!),
                  const SizedBox(height: AppSpacing.lg),
                  _stages(_b!),
                  const SizedBox(height: AppSpacing.lg),
                  _attention(_b!),
                  const SizedBox(height: AppSpacing.lg),
                  FcSectionTitle(context.tr('fc_units'), trailing: _legend()),
                  _unitsGrid(_b!),
                  if (_b!.people.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FcSectionTitle(context.tr('fc_team')),
                    _team(_b!),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _b == null ? null : _bottom(_b!),
    );
  }

  Widget _hero(FullCountBoard b) {
    final pct = (b.progress * 100).round();
    String eta = '—';
    if (b.progress > 0.02 && b.progress < 1 && b.elapsedMinutes > 0) {
      final left = (b.elapsedMinutes / b.progress * (1 - b.progress)).round();
      final t = DateTime.now().add(Duration(minutes: left));
      eta = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    final elapsed = '${b.elapsedMinutes ~/ 60}:${(b.elapsedMinutes % 60).toString().padLeft(2, '0')}';
    Widget vital(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: AppRadius.borderLg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    textDirection: TextDirection.ltr,
                    style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: Fc.accentDark, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!b.session.bookReady)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  b.session.snapshotStatus == 'failed' ? context.tr('fc_book_failed') : context.tr('fc_book_freezing'),
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('fc_counted_units'),
                  style: AppTypography.labelLarge.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              Text('$pct%',
                  style: AppTypography.displayMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.1)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              context.tr('fc_x_of_y_pcs').replaceAll('{x}', fmtInt(b.countedUnits)).replaceAll('{y}', fmtInt(b.bookUnits)),
              style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            Text(context.tr('fc_eta').replaceAll('{t}', eta),
                style: AppTypography.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: AppRadius.borderFull,
          child: LinearProgressIndicator(
            value: b.progress.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          vital(context.tr('fc_items'), '${fmtInt(b.countedItems.toDouble())} / ${fmtInt(b.bookItems.toDouble())}'),
          const SizedBox(width: AppSpacing.sm),
          vital(context.tr('fc_units'), '${b.unitsDone} / ${b.unitsTotal}'),
          const SizedBox(width: AppSpacing.sm),
          vital(context.tr('fc_elapsed'), elapsed),
        ]),
      ]),
    );
  }

  Widget _stages(FullCountBoard b) {
    final stage = _stage(b);
    final labels = [
      context.tr('fc_stage_prep'),
      context.tr('fc_stage_count'),
      context.tr('fc_stage_recount'),
      context.tr('fc_stage_missing'),
      context.tr('fc_stage_approve'),
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < stage ? Fc.accentDark : (i == stage ? AppColors.surface : AppColors.surfaceVariant),
                  border: i == stage ? Border.all(color: Fc.accent, width: 3) : null,
                ),
                child: i < stage
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : Text('${i + 1}',
                        style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w700, color: i == stage ? Fc.accentDark : AppColors.textSecondary)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(labels[i],
                    style: AppTypography.labelSmall.copyWith(
                        fontWeight: i == stage ? FontWeight.w700 : FontWeight.w600,
                        color: i <= stage ? AppColors.textPrimary : AppColors.textSecondary)),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _attention(FullCountBoard b) {
    final rows = <Widget>[];
    void add(IconData icon, Color fg, Color bg, String title, String sub, VoidCallback? onTap) {
      if (rows.isNotEmpty) rows.add(Divider(height: 1, color: AppColors.borderLight));
      rows.add(InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderMd),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              ]),
            ),
            if (onTap != null)
              Icon(AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
          ]),
        ),
      ));
    }

    if (b.recount + b.supervisor > 0) {
      add(Icons.sync_rounded, AppColors.warning, AppColors.warningLight,
          context.tr('fc_att_recount').replaceAll('{n}', '${b.recount + b.supervisor}'),
          b.supervisor > 0
              ? context.tr('fc_att_recount_sup').replaceAll('{n}', '${b.supervisor}')
              : context.tr('fc_att_recount_sub'),
          () => _open(FcRecountPage(sessionId: widget.sessionId)));
    }
    if (b.unitsDone == b.unitsTotal && b.unitsTotal > 0 && b.missing > 0) {
      add(Icons.search_rounded, AppColors.error, AppColors.errorLight,
          context.tr('fc_att_missing').replaceAll('{n}', '${b.missing}'), context.tr('fc_att_missing_sub'),
          () => _open(FcMissingPage(sessionId: widget.sessionId)));
    }
    final slow = b.people.length >= 2
        ? (b.people.toList()..sort((a, c) => a.unitsPerHour.compareTo(c.unitsPerHour))).first
        : null;
    final avg = b.people.isEmpty ? 0 : b.people.map((p) => p.unitsPerHour).reduce((a, c) => a + c) / b.people.length;
    // Only once there is enough counting behind it to mean something.
    if (slow != null && avg > 0 && slow.units >= 150 && slow.unitsPerHour < avg * 0.65) {
      add(Icons.timer_outlined, AppColors.info, AppColors.infoLight,
          context.tr('fc_att_slow').replaceAll('{name}', slow.name),
          context.tr('fc_att_slow_sub').replaceAll('{n}', '${slow.unitsPerHour}'), null);
    }
    if (rows.isEmpty) {
      add(Icons.check_circle_outline_rounded, Fc.accentDark, Fc.soft, context.tr('fc_att_none'),
          context.tr('fc_att_none_sub'), null);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FcSectionTitle(context.tr('fc_attention')),
      FcCard(padding: EdgeInsets.zero, child: Column(children: rows)),
    ]);
  }

  Widget _legend() {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(t, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
        ]);
    return Wrap(spacing: 10, children: [
      dot(Fc.accentDark, context.tr('fc_unit_done')),
      dot(AppColors.warning, context.tr('fc_unit_counting')),
      dot(AppColors.border, context.tr('fc_unit_free')),
    ]);
  }

  Widget _unitsGrid(FullCountBoard b) {
    final cols = context.byWidth(regular: 3, compact: 3, tiny: 2);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final u in b.units)
            SizedBox(
              width: w,
              child: _unitTile(u),
            ),
        ],
      );
    });
  }

  Widget _unitTile(BoardUnit u) {
    final done = u.status == 'done';
    final counting = u.status == 'counting';
    final border = counting ? AppColors.warning : AppColors.border;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg, side: BorderSide(color: border, width: counting ? 2 : 1)),
      child: InkWell(
        borderRadius: AppRadius.borderLg,
        onTap: () => _open(FcUnitPage(sessionId: widget.sessionId, unitCode: u.unitCode)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(u.unitCode,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppTypography.mono.copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
              ),
              if (done) Icon(Icons.check_circle_rounded, size: 16, color: Fc.accentDark),
            ]),
            const SizedBox(height: 2),
            Text(u.name ?? Fc.kindLabel(context, u.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
            if (counting && u.userName != null)
              Text(u.userName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: AppRadius.borderFull,
              child: LinearProgressIndicator(
                value: done ? 1 : u.progress,
                minHeight: 4,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(done ? Fc.accentDark : AppColors.warning),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _team(FullCountBoard b) {
    return FcCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < b.people.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(children: [
              Expanded(child: Text(b.people[i].name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700))),
              Text(context.tr('fc_pcs_per_hour').replaceAll('{n}', fmtInt(b.people[i].unitsPerHour.toDouble())),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget? _bottom(FullCountBoard b) {
    final stage = _stage(b);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: AppButton(
          label: stage >= 4 ? context.tr('fc_go_result') : context.tr('fc_view_result'),
          icon: stage >= 4 ? Icons.verified_outlined : Icons.insights_rounded,
          color: Fc.accentDark,
          variant: stage >= 4 ? AppButtonVariant.filled : AppButtonVariant.tonal,
          onPressed: () => _open(FcResultPage(sessionId: widget.sessionId)),
        ),
      ),
    );
  }
}

/// 27757 → «27,757» with Latin digits (owner's numeral preference).
String fmtInt(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
