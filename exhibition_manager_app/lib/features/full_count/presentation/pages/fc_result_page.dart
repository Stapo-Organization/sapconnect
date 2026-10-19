import 'package:flutter/material.dart';
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
import '../widgets/fc_widgets.dart';
import 'fc_board_page.dart' show fmtInt;

/// Result + approval: accuracy before the count, the money in the variances,
/// the biggest variances, what expires soon, a checklist, the supervisor's
/// approval and the file the accountant posts in SAP (the app never writes to SAP).
class FcResultPage extends StatefulWidget {
  final int sessionId;
  const FcResultPage({super.key, required this.sessionId});

  @override
  State<FcResultPage> createState() => _FcResultPageState();
}

class _FcResultPageState extends State<FcResultPage> {
  final _repo = FullCountRepository();
  FullCountResult? _r;
  FullCountBoard? _b;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Future.wait([_repo.result(widget.sessionId), _repo.board(widget.sessionId)]);
    if (!mounted) return;
    setState(() {
      _r = (res[0] as Res<FullCountResult>).data;
      _b = (res[1] as Res<FullCountBoard>).data;
    });
  }

  bool get _approved => _r?.session.status == 'completed';

  List<(String, bool)> _checks(FullCountBoard b) => [
        (context.tr('fc_chk_book'), b.session.bookReady),
        (context.tr('fc_chk_units'), b.unitsTotal > 0 && b.unitsDone == b.unitsTotal),
        (context.tr('fc_chk_recount'), b.recount + b.supervisor == 0),
        (context.tr('fc_chk_missing'), b.missing == 0),
      ];

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_approve_q')),
        content: Text(context.tr('fc_approve_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('fc_approve'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await _repo.approve(widget.sessionId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    Fc.toast(context, context.tr('fc_approved'));
    _load();
  }

  Future<void> _export({String kind = 'variance'}) async {
    final r = await _repo.exportLink(widget.sessionId, kind: kind);
    if (!mounted) return;
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    await launchUrl(Uri.parse(r.data!), mode: LaunchMode.externalApplication);
  }

  String _money(double v) => '${v < 0 ? '−' : ''}${fmtInt(v.abs())} ${context.tr('currency')}';

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final b = _b;
    final checks = b == null ? <(String, bool)>[] : _checks(b);
    final ready = checks.isNotEmpty && checks.every((c) => c.$2);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_result_title')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: Fc.accent,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  if (!ready && !_approved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: FcCard(
                        color: AppColors.infoLight,
                        borderColor: AppColors.info.withValues(alpha: 0.3),
                        child: Text(context.tr('fc_result_provisional'),
                            style: AppTypography.bodySmall.copyWith(color: AppColors.info, height: 1.6, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  _summary(r),
                  const SizedBox(height: AppSpacing.lg),
                  FcSectionTitle(context.tr('fc_top_variances')),
                  _variances(r),
                  if (r.expiry != null) ..._expiry(r.expiry!),
                  if (!_approved && b != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FcSectionTitle(context.tr('fc_before_approve')),
                    FcCard(
                      child: Column(children: [
                        for (final c in checks)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c.$2 ? Fc.accentDark : Colors.transparent,
                                  border: c.$2 ? null : Border.all(color: AppColors.border, width: 2),
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: c.$2 ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: Text(c.$1, style: AppTypography.bodyMedium)),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: r == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (!_approved && (b?.canManage ?? false))
                    AppButton(
                      label: context.tr('fc_approve'),
                      icon: Icons.verified_rounded,
                      color: Fc.accentDark,
                      loading: _busy,
                      onPressed: ready ? _approve : null,
                    ),
                  // Approving is the owner's: the team sees where it stands, not the button.
                  if (!_approved && !(b?.canManage ?? false))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(context.tr('fc_approve_manager_only'),
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  if (_approved) ...[
                    AppButton(
                      label: context.tr('fc_export'),
                      icon: Icons.download_rounded,
                      color: Fc.accentDark,
                      onPressed: () => _export(),
                    ),
                    const SizedBox(height: 6),
                    Text(context.tr('fc_export_note'),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ]),
              ),
            ),
    );
  }

  Widget _summary(FullCountResult r) {
    final acc = r.accuracy == null ? '—' : '${(r.accuracy! * 100).round()}%';
    Widget tile(String label, String value, Color fg, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderLg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTypography.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppTypography.titleLarge.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
    return FcCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('fc_accuracy_before'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
              Text(context.tr('fc_accuracy_sub'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
          Text(acc, style: AppTypography.headlineLarge.copyWith(color: Fc.accentDark, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          tile(context.tr('fc_items_counted'), fmtInt(r.items.toDouble()), AppColors.textPrimary, AppColors.surfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          tile(context.tr('fc_items_variance'), fmtInt(r.withVariance.toDouble()), AppColors.textPrimary, AppColors.surfaceVariant),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          tile(context.tr('fc_over_value'), _money(r.overValue), Fc.accentDark, Fc.soft),
          const SizedBox(width: AppSpacing.sm),
          tile(context.tr('fc_short_value'), _money(r.shortValue), AppColors.error, AppColors.errorLight),
        ]),
      ]),
    );
  }

  // ─── Expiry ──────────────────────────────────────────────────

  static const _soonShown = 30;
  static const _mismatchShown = 15;

  (Color, Color) _bucketColors(String? bucket) => switch (bucket) {
        'expired' => (AppColors.error, AppColors.errorLight),
        'd30' || 'd60' => (AppColors.warning, AppColors.warningLight),
        _ => (AppColors.textPrimary, AppColors.surfaceVariant),
      };

  List<Widget> _expiry(ExpiryReport e) {
    final arabic = AppLocalizations.isArabic;
    Widget tile(String key) {
      final b = e.buckets[key] ?? const ExpiryBucket();
      final (fg, bg) = _bucketColors(key);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderLg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('fc_exp_b_$key'), style: AppTypography.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(context.tr('fc_exp_items').replaceAll('{n}', fmtInt(b.items.toDouble())),
                style: AppTypography.titleMedium.copyWith(color: fg, fontWeight: FontWeight.w700)),
            Text('${Fc.qty(b.units)} ${context.tr('fc_pcs')} · ${_money(b.value)}',
                style: AppTypography.labelSmall.copyWith(color: fg)),
          ]),
        ),
      );
    }

    Widget row(ExpiryRow x, {bool mismatch = false}) {
      final (fg, bg) = _bucketColors(x.bucket);
      final where = x.locations.isEmpty ? '' : '  ·  ${x.locations.join(' ')}';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.product.name(arabic),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              Text(
                mismatch
                    ? context.tr('fc_exp_sap_has').replaceAll(
                        '{d}', x.sapDates.map((d) => ExpirySplit(date: d, qty: 0).label).join('، '))
                    : '${Fc.qty(x.split.qty)} ${context.tr('fc_pcs')}$where',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderFull),
              child: Text(x.split.label,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.labelLarge.copyWith(color: fg, fontWeight: FontWeight.w700)),
            ),
            Text(
                x.days < 0
                    ? context.tr('fc_exp_expired')
                    : context.tr('fc_exp_days').replaceAll('{n}', '${x.days}'),
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          ]),
        ]),
      );
    }

    Widget list(List<ExpiryRow> rows, {bool mismatch = false}) => FcCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.borderLight),
              row(rows[i], mismatch: mismatch),
            ],
          ]),
        );

    final soon = e.soon.take(_soonShown).toList();
    final mismatch = e.mismatch.take(_mismatchShown).toList();
    return [
      const SizedBox(height: AppSpacing.lg),
      FcSectionTitle(context.tr('fc_exp_section')),
      FcCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [tile('expired'), const SizedBox(width: AppSpacing.sm), tile('d30')]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [tile('d60'), const SizedBox(width: AppSpacing.sm), tile('d90')]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('fc_exp_coverage')
                .replaceAll('{a}', fmtInt(e.linesWithDate.toDouble()))
                .replaceAll('{b}', fmtInt(e.lines.toDouble()))
                .replaceAll('{c}', fmtInt(e.linesNoDate.toDouble())),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ]),
      ),
      if (soon.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        list(soon),
        if (e.soon.length > soon.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.tr('fc_exp_more').replaceAll('{n}', fmtInt((e.soon.length - soon.length).toDouble())),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
      ],
      if (e.mismatchTotal > 0) ...[
        const SizedBox(height: AppSpacing.lg),
        FcSectionTitle(context.tr('fc_exp_mismatch').replaceAll('{n}', fmtInt(e.mismatchTotal.toDouble()))),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(context.tr('fc_exp_mismatch_hint'),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ),
        list(mismatch, mismatch: true),
      ],
      const SizedBox(height: AppSpacing.md),
      AppButton(
        label: context.tr('fc_exp_export'),
        icon: Icons.download_rounded,
        variant: AppButtonVariant.tonal,
        color: Fc.accentDark,
        onPressed: e.linesWithDate > 0 ? () => _export(kind: 'expiry') : null,
      ),
    ];
  }

  Widget _variances(FullCountResult r) {
    if (r.topVariances.isEmpty) {
      return FcCard(child: Text(context.tr('fc_no_variances'), style: AppTypography.bodyMedium));
    }
    final arabic = AppLocalizations.isArabic;
    return FcCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < r.topVariances.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.borderLight),
          Builder(builder: (_) {
            final v = r.topVariances[i];
            final up = v.variance > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.product.name(arabic),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      context.tr('fc_counted_vs_book').replaceAll('{c}', Fc.qty(v.countedQty)).replaceAll('{b}', Fc.qty(v.systemQty)),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: up ? Fc.soft : AppColors.errorLight,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text('${up ? '+' : '−'}${Fc.qty(v.variance.abs())}',
                        textDirection: TextDirection.ltr,
                        style: AppTypography.labelLarge.copyWith(
                            color: up ? Fc.accentDark : AppColors.error, fontWeight: FontWeight.w700)),
                  ),
                  if (v.varianceValue != null)
                    Text(_money(v.varianceValue!), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                ]),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}
