import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/storage/secure_storage.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../widgets/fc_widgets.dart';
import 'fc_count_page.dart';

/// «منطقتي»: one display unit — claim it, see its shelves, count, hand it back.
class FcUnitPage extends StatefulWidget {
  final int sessionId;
  final String unitCode;
  const FcUnitPage({super.key, required this.sessionId, required this.unitCode});

  @override
  State<FcUnitPage> createState() => _FcUnitPageState();
}

class _FcUnitPageState extends State<FcUnitPage> {
  final _repo = FullCountRepository();
  FullCountBoard? _board;
  BoardUnit? _unit;
  int? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _me ??= ((await SecureStorage.getUserData())?['id'] as num?)?.toInt();
    final r = await _repo.board(widget.sessionId);
    if (!mounted || !r.ok) return;
    setState(() {
      _board = r.data;
      _unit = r.data!.units.where((u) => u.unitCode == widget.unitCode).firstOrNull;
    });
  }

  bool get _manager => _board?.canManage ?? false;
  bool get _mine => _unit?.status == 'counting' && _unit?.userId == _me;
  bool get _others => _unit?.status == 'counting' && _unit?.userId != _me;

  /// The unit this counter still holds elsewhere: one open unit at a time.
  BoardUnit? get _myOpenElsewhere => _board?.units
      .where((x) => x.unitCode != widget.unitCode && x.status == 'counting' && x.userId == _me)
      .firstOrNull;

  Future<void> _act(String action, {bool closePrevious = false, int? userId, String? toast}) async {
    setState(() => _busy = true);
    final r = await _repo.unitAction(widget.sessionId, widget.unitCode, action, closePrevious: closePrevious, userId: userId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      _load();
      return;
    }
    if (toast != null) Fc.toast(context, toast);
    if (action == 'done' && !_manager) {
      Fc.toast(context, context.tr('fc_unit_handed').replaceAll('{u}', widget.unitCode));
      Navigator.pop(context);
      return;
    }
    await _load();
    if (action == 'claim' && mounted) _count();
  }

  /// Taking a unit while another is still open asks to close that one first.
  Future<void> _claim() async {
    final other = _myOpenElsewhere;
    if (other == null) return _act('claim');
    final left = other.shelves - other.countedShelves.length;
    final go = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_close_prev_q').replaceAll('{u}', other.unitCode)),
        content: Text(left > 0
            ? context.tr('fc_close_prev_left').replaceAll('{u}', other.unitCode).replaceAll('{n}', '$left')
            : context.tr('fc_close_prev_body').replaceAll('{u}', other.unitCode)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'back'), child: Text(context.tr('fc_back_to_unit').replaceAll('{u}', other.unitCode))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'switch'),
            child: Text(context.tr('fc_close_prev_go').replaceAll('{u}', other.unitCode)),
          ),
        ],
      ),
    );
    if (!mounted || go == null) return;
    if (go == 'back') {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => FcUnitPage(sessionId: widget.sessionId, unitCode: other.unitCode)));
      return;
    }
    await _act('claim', closePrevious: true);
  }

  /// «Finished» with shelves still blank: fine when they are really empty — ask once.
  Future<void> _finish() async {
    final u = _unit!;
    final left = u.shelves - u.countedShelves.length;
    if (left > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('fc_finish_left_q').replaceAll('{n}', '$left')),
          content: Text(context.tr('fc_finish_left_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('fc_continue_count'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('fc_finish_anyway'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await _act('done', toast: _manager && !_mine ? context.tr('fc_unit_closed').replaceAll('{u}', u.unitCode) : null);
  }

  /// The manager hands the unit to someone on the team (from the board).
  Future<void> _assign() async {
    final team = _board?.team ?? const <TeamMember>[];
    final holding = {
      for (final x in _board?.units ?? const <BoardUnit>[])
        if (x.status == 'counting' && x.userId != null) x.userId!: x.unitCode,
    };
    final pick = await showModalBottomSheet<TeamMember>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
            child: Text(context.tr('fc_assign_title').replaceAll('{u}', widget.unitCode),
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
          ),
          for (final m in team)
            ListTile(
              enabled: m.userId != _unit?.userId || _unit?.status != 'counting',
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(m.name),
              subtitle: holding[m.userId] != null
                  ? Text(context.tr('fc_assign_holding').replaceAll('{u}', holding[m.userId]!),
                      style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600))
                  : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    await _act('assign',
        userId: pick.userId,
        toast: context.tr('fc_unit_assigned').replaceAll('{u}', widget.unitCode).replaceAll('{name}', pick.name));
  }

  Future<void> _count() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FcCountPage(sessionId: widget.sessionId, unitCode: widget.unitCode)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = _unit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_my_unit')),
      body: u == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                FcCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      UnitBadge(code: u.unitCode, kind: u.kind, size: 64),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${Fc.kindLabel(context, u.kind)}${u.name != null ? ' · ${u.name}' : ''}',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(context.tr('fc_n_shelves').replaceAll('{n}', '${u.shelves}'),
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                          if (_others)
                            Text(context.tr('fc_counted_by').replaceAll('{name}', u.userName ?? ''),
                                style: AppTypography.bodySmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: _stat(context.tr('fc_shelves_done'), '${u.countedShelves.length} / ${u.shelves}'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _stat(context.tr('fc_status'), context.tr('fc_unit_${u.status}'))),
                    ]),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),
                FcSectionTitle(context.tr('fc_shelves')),
                FcCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < u.shelfCodes.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: AppColors.borderLight),
                      _shelfRow(u, u.shelfCodes[i], i),
                    ],
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),
                _rules(),
              ],
            ),
      bottomNavigationBar: u == null ? null : _bottom(u),
    );
  }

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.borderLg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          Text(value, textDirection: TextDirection.ltr, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _shelfRow(BoardUnit u, String code, int i) {
    final done = u.countedShelves.contains(code);
    final firstOpen = u.shelfCodes.firstWhere((c) => !u.countedShelves.contains(c), orElse: () => '');
    final here = _mine && code == firstOpen;
    return Container(
      color: here ? AppColors.warningLight.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? Fc.soft : (here ? AppColors.warning : AppColors.surfaceVariant),
            borderRadius: AppRadius.borderMd,
          ),
          child: done
              ? Icon(Icons.check_rounded, color: Fc.accentDark, size: 20)
              : Text('${i + 1}',
                  style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700, color: here ? Colors.white : AppColors.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(code, textDirection: TextDirection.ltr, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            i == 0 ? context.tr('fc_top_shelf') : (i == u.shelfCodes.length - 1 ? context.tr('fc_bottom_shelf') : ''),
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
        Text(done ? context.tr('fc_counted') : (here ? context.tr('fc_next') : ''),
            style: AppTypography.labelMedium.copyWith(
                color: done ? Fc.accentDark : AppColors.warning, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _rules() {
    Widget rule(IconData icon, String title, String body, {bool warn = false}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: warn ? AppColors.errorLight : Fc.soft, borderRadius: AppRadius.borderSm),
              child: Icon(icon, size: 17, color: warn ? AppColors.error : Fc.accentDark),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: body),
              ]), style: AppTypography.bodySmall.copyWith(height: 1.6)),
            ),
          ]),
        );
    return FcCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('fc_rules'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        rule(Icons.visibility_off_outlined, context.tr('fc_rule_blind_t'), context.tr('fc_rule_blind')),
        rule(Icons.qr_code_2_rounded, context.tr('fc_rule_label_t'), context.tr('fc_rule_label')),
        rule(Icons.inventory_2_outlined, context.tr('fc_rule_carton_t'), context.tr('fc_rule_carton')),
        rule(Icons.report_outlined, context.tr('fc_rule_damaged_t'), context.tr('fc_rule_damaged'), warn: true),
      ]),
    );
  }

  Widget _bottom(BoardUnit u) {
    final children = <Widget>[];
    void gap() => children.add(const SizedBox(height: AppSpacing.sm));
    if (u.status == 'free' || u.status == 'done') {
      children.add(AppButton(
        label: u.status == 'done' ? context.tr('fc_reopen_unit') : context.tr('fc_take_unit'),
        icon: Icons.play_arrow_rounded,
        color: Fc.accentDark,
        loading: _busy,
        onPressed: _claim,
      ));
      if (_manager) {
        gap();
        children.add(AppButton(
          label: context.tr('fc_assign_unit'),
          icon: Icons.person_add_alt_rounded,
          variant: AppButtonVariant.outline,
          color: AppColors.textPrimary,
          onPressed: _busy ? null : _assign,
        ));
      }
    } else if (_mine) {
      children.addAll([
        AppButton(label: context.tr('fc_continue_count'), icon: Icons.qr_code_scanner_rounded, color: Fc.accentDark, onPressed: _count),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: context.tr('fc_unit_finished'),
          variant: AppButtonVariant.outline,
          color: AppColors.textPrimary,
          loading: _busy,
          onPressed: _finish,
        ),
      ]);
      if (_manager) {
        gap();
        children.add(AppButton(
          label: context.tr('fc_assign_unit'),
          icon: Icons.swap_horiz_rounded,
          variant: AppButtonVariant.tonal,
          color: AppColors.textSecondary,
          onPressed: _busy ? null : _assign,
        ));
      }
    } else if (_manager) {
      // Someone else holds it: the manager can move it, close it or free it.
      children.addAll([
        AppButton(
          label: context.tr('fc_assign_other'),
          icon: Icons.swap_horiz_rounded,
          color: Fc.accentDark,
          loading: _busy,
          onPressed: _assign,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: AppButton(
              label: context.tr('fc_unit_finished'),
              variant: AppButtonVariant.outline,
              color: AppColors.textPrimary,
              onPressed: _busy ? null : _finish,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: context.tr('fc_release_unit'),
              variant: AppButtonVariant.outline,
              color: AppColors.textSecondary,
              onPressed: _busy ? null : () => _act('release', toast: context.tr('fc_unit_released').replaceAll('{u}', u.unitCode)),
            ),
          ),
        ]),
      ]);
    } else {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(context.tr('fc_unit_ask_manager').replaceAll('{name}', u.userName ?? ''),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ));
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
