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
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/quality_admin_models.dart';
import '../../data/quality_admin_repository.dart';
import 'quality_submission_page.dart';
import 'quality_task_create_page.dart';

/// Owner-side Quality Tasks management: templates list (with create + activate
/// + generate-now) and cross-store follow-up of task instances.
class QualityAdminPage extends StatefulWidget {
  const QualityAdminPage({super.key});

  @override
  State<QualityAdminPage> createState() => _QualityAdminPageState();
}

class _QualityAdminPageState extends State<QualityAdminPage> {
  final QualityAdminRepository _repo = QualityAdminRepository();
  int _tab = 0; // 0 = templates, 1 = follow-up

  List<QualityTemplate> _templates = [];
  bool _tLoading = true;
  bool _tError = false;

  List<QualityInstanceRow> _instances = [];
  bool _iLoading = false;
  bool _iError = false;
  String _iStatus = 'pending'; // pending | submitted | ''(all)

  Color get _accent => AppDomain.quality.accent;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _tLoading = _templates.isEmpty;
      _tError = false;
    });
    final r = await _repo.getTemplates();
    if (!mounted) return;
    setState(() {
      _templates = r.templates;
      _tLoading = false;
      _tError = !r.success;
    });
  }

  Future<void> _loadInstances() async {
    setState(() {
      _iLoading = true;
      _iError = false;
    });
    final r = await _repo.getInstances(status: _iStatus);
    if (!mounted) return;
    setState(() {
      _instances = r.instances;
      _iLoading = false;
      _iError = !r.success;
    });
  }

  void _switchTab(int i) {
    setState(() => _tab = i);
    if (i == 1 && _instances.isEmpty && !_iLoading) _loadInstances();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QualityTaskCreatePage()),
    );
    if (created == true) _loadTemplates();
  }

  Future<void> _toggle(QualityTemplate t) async {
    final r = await _repo.toggleActive(t.id, !t.isActive);
    if (!mounted) return;
    if (r.success) {
      _loadTemplates();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.error ?? '')));
    }
  }

  Future<void> _generate(QualityTemplate t) async {
    final r = await _repo.generateNow(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.success ? context.tr('qa_generated_done') : (r.error ?? ''))),
    );
    if (r.success) _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final canManage = AppSession.can(Ability.qualityAdminManage);
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('qa_title')),
        floatingActionButton: (_tab == 0 && canManage)
            ? FloatingActionButton.extended(
                onPressed: _openCreate,
                backgroundColor: _accent,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(context.tr('qa_create'), style: const TextStyle(color: Colors.white)),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: AppSegmentedControl(
                activeColor: _accent,
                selectedIndex: _tab,
                onChanged: _switchTab,
                items: [
                  SegmentItem(context.tr('qa_tab_templates'), icon: Icons.list_alt_rounded),
                  SegmentItem(context.tr('qa_tab_followup'), icon: Icons.fact_check_outlined),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? _templatesView(context) : _followupView(context)),
          ],
        ),
      ),
    );
  }

  Widget _templatesView(BuildContext context) {
    if (_tLoading) return const SkeletonList(itemCount: 5, cardHeight: 96);
    if (_tError) return ErrorStateWidget(onRetry: _loadTemplates);
    if (_templates.isEmpty) {
      return EmptyState(icon: Icons.assignment_outlined, title: context.tr('qa_no_templates'));
    }
    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.massive),
        itemCount: _templates.length,
        itemBuilder: (_, i) => _templateCard(context, _templates[i]),
      ),
    );
  }

  Widget _templateCard(BuildContext context, QualityTemplate t) {
    final canManage = AppSession.can(Ability.qualityAdminManage);
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
                    Text(t.title, style: AppTypography.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${t.warehouseName} · ${context.tr('rec_${t.recurrence}')}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              if (canManage)
                Switch.adaptive(
                  value: t.isActive,
                  activeThumbColor: _accent,
                  onChanged: (_) => _toggle(t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _statChip(context.tr('qa_pending'), t.pendingCount, AppColors.warning),
              _statChip(context.tr('qa_submitted'), t.submittedCount, AppColors.success),
              if (t.overdueCount > 0) _statChip(context.tr('qa_overdue'), t.overdueCount, AppColors.error),
              if (canManage && t.recurrence == 'once')
                ActionChip(
                  avatar: Icon(Icons.play_arrow_rounded, size: 16, color: _accent),
                  label: Text(context.tr('qa_generate_now'), style: AppTypography.labelSmall.copyWith(color: _accent)),
                  onPressed: () => _generate(t),
                  backgroundColor: _accent.withValues(alpha: 0.1),
                  side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.borderFull),
      child: Text('$label: $count',
          style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _followupView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
          child: AppSegmentedControl(
            activeColor: _accent,
            selectedIndex: _iStatus == 'pending' ? 0 : (_iStatus == 'submitted' ? 1 : 2),
            onChanged: (i) {
              _iStatus = i == 0 ? 'pending' : (i == 1 ? 'submitted' : '');
              _loadInstances();
            },
            items: [
              SegmentItem(context.tr('qa_pending')),
              SegmentItem(context.tr('qa_submitted')),
              SegmentItem(context.tr('all')),
            ],
          ),
        ),
        Expanded(
          child: _iLoading
              ? const SkeletonList(itemCount: 6, cardHeight: 72)
              : _iError
                  ? ErrorStateWidget(onRetry: _loadInstances)
                  : _instances.isEmpty
                      ? EmptyState(icon: Icons.fact_check_outlined, title: context.tr('qa_no_instances'))
                      : RefreshIndicator(
                          onRefresh: _loadInstances,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xxl),
                            itemCount: _instances.length,
                            itemBuilder: (_, i) => _instanceCard(context, _instances[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _instanceCard(BuildContext context, QualityInstanceRow r) {
    final statusColor = r.status == 'submitted'
        ? AppColors.success
        : r.isOverdue
            ? AppColors.error
            : AppColors.warning;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QualitySubmissionPage(instanceId: r.id, initialTitle: r.title),
        ),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: AppTypography.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${r.warehouseName}${r.scheduledDate != null ? ' · ${r.scheduledDate}' : ''}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          if (r.isOverdue && r.status == 'pending')
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: Text(context.tr('qa_overdue'),
                  style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
            ),
          Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}
