import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';

import '../../data/models/quality_admin_models.dart';
import '../../data/quality_admin_repository.dart';

/// Create a quality-task template (recurring) or an immediate one-off task,
/// assigned to one or more stores. Mirrors the fields of the Filament resource.
class QualityTaskCreatePage extends StatefulWidget {
  const QualityTaskCreatePage({super.key});

  @override
  State<QualityTaskCreatePage> createState() => _QualityTaskCreatePageState();
}

class _QualityTaskCreatePageState extends State<QualityTaskCreatePage> {
  final QualityAdminRepository _repo = QualityAdminRepository();

  final _title = TextEditingController();
  final _description = TextEditingController();

  String _proofType = 'photo'; // acknowledge | photo | checklist
  int _minPhotos = 1;
  bool _requireComment = false;
  final List<({TextEditingController label, bool requirePhoto})> _checklist = [];

  String _recurrence = 'daily'; // once | daily | weekly
  final Set<int> _days = {};
  String _priority = 'medium';

  List<WarehouseRef> _warehouses = [];
  final Set<String> _selectedWarehouses = {};
  bool _loadingWarehouses = true;
  bool _saving = false;

  static const _proofTypes = ['acknowledge', 'photo', 'checklist'];
  static const _recurrences = ['once', 'daily', 'weekly'];
  static const _priorities = ['high', 'medium', 'low'];

  Color get _accent => AppDomain.quality.accent;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final c in _checklist) {
      c.label.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final r = await _repo.getWarehouses();
    if (!mounted) return;
    setState(() {
      _warehouses = r.warehouses;
      _loadingWarehouses = false;
    });
  }

  void _addChecklistItem() {
    setState(() => _checklist.add((label: TextEditingController(), requirePhoto: true)));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _toast(context.tr('qa_title_label'));
      return;
    }
    if (_selectedWarehouses.isEmpty) {
      _toast(context.tr('qa_select_warehouse_first'));
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'proof_type': _proofType,
      'recurrence': _recurrence,
      'priority': _priority,
      'is_active': true,
      'warehouse_codes': _selectedWarehouses.toList(),
    };
    if (_proofType == 'photo') {
      payload['min_photos'] = _minPhotos;
      payload['require_comment'] = _requireComment;
    }
    if (_proofType == 'checklist') {
      payload['checklist_items'] = _checklist
          .where((c) => c.label.text.trim().isNotEmpty)
          .map((c) => {'label': c.label.text.trim(), 'require_photo': c.requirePhoto})
          .toList();
    }
    if (_recurrence == 'weekly') {
      payload['days_of_week'] = _days.toList();
    }

    setState(() => _saving = true);
    final r = await _repo.createTask(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      _toast(context.tr('qa_created_done'));
      Navigator.of(context).pop(true);
    } else {
      _toast(r.error ?? '');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('qa_create')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: AppButton(
              label: context.tr('qa_save'),
              icon: Icons.check_rounded,
              loading: _saving,
              color: _accent,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            _field(context.tr('qa_title_label'), _title),
            const SizedBox(height: AppSpacing.base),
            _field(context.tr('qa_description_label'), _description, maxLines: 2),
            const SizedBox(height: AppSpacing.lg),

            _label(context.tr('qa_proof_type')),
            AppSegmentedControl(
              activeColor: _accent,
              selectedIndex: _proofTypes.indexOf(_proofType),
              onChanged: (i) => setState(() => _proofType = _proofTypes[i]),
              items: [
                SegmentItem(context.tr('proof_acknowledge')),
                SegmentItem(context.tr('proof_photo')),
                SegmentItem(context.tr('proof_checklist')),
              ],
            ),
            ..._proofExtras(context),
            const SizedBox(height: AppSpacing.lg),

            _label(context.tr('qa_recurrence')),
            AppSegmentedControl(
              activeColor: _accent,
              selectedIndex: _recurrences.indexOf(_recurrence),
              onChanged: (i) => setState(() => _recurrence = _recurrences[i]),
              items: [
                SegmentItem(context.tr('rec_once')),
                SegmentItem(context.tr('rec_daily')),
                SegmentItem(context.tr('rec_weekly')),
              ],
            ),
            if (_recurrence == 'weekly') ...[
              const SizedBox(height: AppSpacing.sm),
              _daysOfWeek(context),
            ],
            const SizedBox(height: AppSpacing.lg),

            _label(context.tr('qa_priority')),
            AppSegmentedControl(
              activeColor: _accent,
              selectedIndex: _priorities.indexOf(_priority),
              onChanged: (i) => setState(() => _priority = _priorities[i]),
              items: [
                SegmentItem(context.tr('priority_high')),
                SegmentItem(context.tr('priority_medium')),
                SegmentItem(context.tr('priority_low')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            _label(context.tr('qa_warehouses')),
            _warehousePicker(context),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
      );

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }

  List<Widget> _proofExtras(BuildContext context) {
    if (_proofType == 'photo') {
      return [
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(context.tr('qa_min_photos'), style: AppTypography.bodyMedium)),
                  IconButton(
                    onPressed: _minPhotos > 1 ? () => setState(() => _minPhotos--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_minPhotos', style: AppTypography.titleMedium),
                  IconButton(
                    onPressed: _minPhotos < 30 ? () => setState(() => _minPhotos++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('qa_require_comment'), style: AppTypography.bodyMedium),
                value: _requireComment,
                activeThumbColor: _accent,
                onChanged: (v) => setState(() => _requireComment = v),
              ),
            ],
          ),
        ),
      ];
    }
    if (_proofType == 'checklist') {
      return [
        const SizedBox(height: AppSpacing.md),
        ..._checklist.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: item.label,
                        decoration: InputDecoration(hintText: context.tr('qa_item_label'), border: InputBorder.none),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _checklist.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.tr('qa_item_require_photo'), style: AppTypography.labelMedium),
                  value: item.requirePhoto,
                  activeThumbColor: _accent,
                  onChanged: (v) => setState(() => _checklist[i] = (label: item.label, requirePhoto: v)),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addChecklistItem,
          icon: Icon(Icons.add_rounded, color: _accent),
          label: Text(context.tr('qa_add_item'), style: TextStyle(color: _accent)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: _accent.withValues(alpha: 0.4))),
        ),
      ];
    }
    return [];
  }

  Widget _daysOfWeek(BuildContext context) {
    const labels = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: List.generate(7, (d) {
        final selected = _days.contains(d);
        return PillChip(
          label: labels[d],
          selected: selected,
          color: _accent,
          onTap: () => setState(() => selected ? _days.remove(d) : _days.add(d)),
        );
      }),
    );
  }

  Widget _warehousePicker(BuildContext context) {
    if (_loadingWarehouses) {
      return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.base), child: CircularProgressIndicator()));
    }
    if (_warehouses.isEmpty) {
      return Text(context.tr('rd_no_branches'), style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary));
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _warehouses.map((w) {
        final selected = _selectedWarehouses.contains(w.code);
        return PillChip(
          label: w.name,
          selected: selected,
          color: _accent,
          onTap: () => setState(() => selected ? _selectedWarehouses.remove(w.code) : _selectedWarehouses.add(w.code)),
        );
      }).toList(),
    );
  }
}
