import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/design_system/theme/theme_controller.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/full_screen_image_viewer.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/models/quality_task_models.dart';
import '../../data/quality_control_repository.dart';

/// Read-only viewer for the owner: opens a task instance and shows its captured
/// content — proof photos as a professional tap-to-zoom gallery, the executor's
/// notes, and (for checklists) each item with its own photos. No edit controls.
class QualitySubmissionPage extends StatefulWidget {
  final int instanceId;
  final String initialTitle;
  const QualitySubmissionPage({super.key, required this.instanceId, this.initialTitle = ''});

  @override
  State<QualitySubmissionPage> createState() => _QualitySubmissionPageState();
}

class _QualitySubmissionPageState extends State<QualitySubmissionPage> {
  final QualityControlRepository _repo = QualityControlRepository();
  QualityTaskInstance? _task;
  bool _loading = true;
  bool _hasError = false;

  Color get _accent => AppDomain.quality.accent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _task == null;
      _hasError = false;
    });
    final res = await _repo.getTask(widget.instanceId);
    if (!mounted) return;
    setState(() {
      _task = res.task ?? _task;
      _hasError = !res.success && _task == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppThemeMode>(
        valueListenable: AppThemeController.modeNotifier,
        builder: (context, _, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final t = _task;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: t?.title ?? widget.initialTitle),
        body: RefreshIndicator(
          onRefresh: _load,
          color: _accent,
          child: _loading
              ? ListView(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  children: const [SkeletonCard(height: 120), SizedBox(height: 12), SkeletonCard(height: 220)],
                )
              : _hasError || t == null
                  ? ListView(children: [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _load))])
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        _headerCard(context, t),
                        if (t.comment != null && t.comment!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.base),
                          _notesCard(context, t.comment!.trim()),
                        ],
                        const SizedBox(height: AppSpacing.base),
                        ..._content(context, t),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, QualityTaskInstance t) {
    final isArabic = AppLocalizations.isArabic;
    final slot = t.slotLabel(isArabic);
    final (statusColor, statusKey, statusIcon) = t.isSubmitted
        ? (AppColors.success, 'qa_submitted', Icons.check_circle_rounded)
        : t.isOverdue
            ? (AppColors.error, 'qa_overdue', Icons.warning_amber_rounded)
            : (AppColors.warning, 'qa_pending', Icons.schedule_rounded);
    final statusBadge = StatusBadge(label: context.tr(statusKey), color: statusColor, icon: statusIcon);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              ),
              // شارة «متأخرة» تهتز مرة واحدة للفت النظر.
              if (!t.isSubmitted && t.isOverdue) WiggleIcon(child: statusBadge) else statusBadge,
            ],
          ),
          if (t.description != null && t.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.description!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatChip(icon: Icons.store_rounded, label: t.warehouseName ?? t.warehouseCode),
              if (slot.isNotEmpty) StatChip(icon: Icons.schedule_rounded, label: slot, color: AppColors.accentDark),
              if (t.scheduledDate != null) StatChip(icon: Icons.event_rounded, label: t.scheduledDate!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesCard(BuildContext context, String comment) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, size: 18, color: _accent),
              const SizedBox(width: AppSpacing.sm),
              Text(context.tr('qs_notes'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(comment, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, QualityTaskInstance t) {
    final r = t.requirements;
    if (r.isAcknowledge) {
      return [_acknowledgeCard(context)];
    }
    if (r.isChecklist) {
      return [
        _sectionHeader(context, context.tr('qs_content'), t.photos.length),
        const SizedBox(height: AppSpacing.sm),
        for (final item in r.checklistItems) _checklistBlock(context, t, item),
      ];
    }
    // photo proof
    final photos = t.generalPhotos.isNotEmpty ? t.generalPhotos : t.photos;
    return [
      _sectionHeader(context, context.tr('qs_content'), photos.length),
      const SizedBox(height: AppSpacing.sm),
      if (photos.isEmpty) _noPhotos(context) else _gallery(context, photos),
    ];
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
            child: Text('$count ${context.tr('qs_photos_count')}',
                style: AppTypography.labelSmall.copyWith(color: _accent, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _acknowledgeCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.task_alt_rounded, color: AppColors.success, size: 38),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('qs_acknowledged'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _noPhotos(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(context.tr('qs_no_photos'),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _checklistBlock(BuildContext context, QualityTaskInstance t, QualityChecklistItem item) {
    final photos = t.photosForItem(item.key);
    final done = t.isSubmitted || photos.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: done ? AppColors.success : AppColors.textTertiary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(item.label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _gallery(context, photos),
          ],
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, List<QualityTaskPhoto> photos) {
    final urls = photos.map((p) => p.url).toList();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.sm;
        const cols = 3;
        final tile = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < photos.length; i++)
              GestureDetector(
                onTap: () => showFullScreenGallery(context, urls, initialIndex: i),
                child: Hero(
                  tag: 'qphoto_${photos[i].id}',
                  child: ClipRRect(
                    borderRadius: AppRadius.borderMd,
                    child: CachedNetworkImage(
                      imageUrl: photos[i].url,
                      width: tile,
                      height: tile,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: tile,
                        height: tile,
                        color: AppColors.surfaceVariant,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _accent.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: tile,
                        height: tile,
                        color: AppColors.surfaceVariant,
                        child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
