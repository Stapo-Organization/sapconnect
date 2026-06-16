import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/quality_control/data/quality_control_repository.dart';
import 'package:exhibition_manager_app/features/quality_control/data/models/quality_task_models.dart';
import 'package:exhibition_manager_app/features/gamification/presentation/widgets/celebration_overlay.dart';

/// Guided quality-task execution — renders dynamically by proof type
/// (acknowledge / photo / checklist). Server-side validation is authoritative.
class QualityTaskDetailPage extends StatefulWidget {
  final int instanceId;
  const QualityTaskDetailPage({super.key, required this.instanceId});

  @override
  State<QualityTaskDetailPage> createState() => _QualityTaskDetailPageState();
}

class _QualityTaskDetailPageState extends State<QualityTaskDetailPage> {
  final QualityControlRepository _repo = QualityControlRepository();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _comment = TextEditingController();

  QualityTaskInstance? _task;
  bool _loading = true;
  bool _hasError = false;
  bool _busy = false; // uploading or submitting
  final Set<String> _localChecked = {}; // non-photo checklist items ticked

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getTask(widget.instanceId);
    if (mounted) {
      setState(() {
        _task = res.task;
        _loading = false;
        _hasError = !res.success || _task == null;
        if (_task?.comment != null && _comment.text.isEmpty) _comment.text = _task!.comment!;
      });
    }
  }

  Future<void> _reload() async {
    final res = await _repo.getTask(widget.instanceId);
    if (mounted && res.task != null) setState(() => _task = res.task);
  }

  Future<void> _pickAndUpload({String? itemKey}) async {
    // Quality evidence must be captured live — camera only, no gallery.
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    final res = await _repo.uploadPhotos(widget.instanceId, [file.path], checklistItemKey: itemKey);
    if (!mounted) return;
    if (res.success) {
      await _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(res.error ?? context.tr('unexpected_error'))),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deletePhoto(int photoId) async {
    setState(() => _busy = true);
    final res = await _repo.deletePhoto(widget.instanceId, photoId);
    if (!mounted) return;
    if (res.success) {
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    final t = _task!;
    setState(() => _busy = true);

    Map<String, dynamic>? checklistResults;
    if (t.requirements.isChecklist) {
      checklistResults = {
        for (final item in t.requirements.checklistItems) item.key: {'checked': true},
      };
    }

    final res = await _repo.submit(widget.instanceId, comment: _comment.text.trim(), checklistResults: checklistResults);
    if (!mounted) return;
    if (res.success) {
      if (res.gamification != null) {
        await showCelebration(context, res.gamification!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.success, content: Text(context.tr('task_submitted'))),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text(res.error ?? context.tr('unexpected_error'))),
      );
    }
  }

  // ─── Completion gating (mirrors the server) ─────────────────
  bool get _canSubmit {
    final t = _task;
    if (t == null || t.isSubmitted) return false;
    final r = t.requirements;
    if (r.isAcknowledge) return true;
    if (r.isPhoto) {
      final ok = t.generalPhotos.length >= r.minPhotos;
      return ok && (!r.requireComment || _comment.text.trim().isNotEmpty);
    }
    // checklist: every item done
    return r.checklistItems.every(_itemDone);
  }

  bool _itemDone(QualityChecklistItem item) =>
      item.requirePhoto ? _task!.photosForItem(item.key).isNotEmpty : _localChecked.contains(item.key);

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final t = _task;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: t?.title ?? context.tr('quality_tasks')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasError || t == null
                ? ErrorStateWidget(onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppDomain.quality.accent,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      children: [
                        _buildHeader(t),
                        const SizedBox(height: AppSpacing.base),
                        if (t.requirements.isAcknowledge) _buildAcknowledge(t),
                        if (t.requirements.isPhoto) _buildPhoto(t),
                        if (t.requirements.isChecklist) _buildChecklist(t),
                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
        bottomNavigationBar: (t != null && t.isPending) ? _buildBottom(t) : null,
      ),
    );
  }

  Widget _buildHeader(QualityTaskInstance t) {
    final isArabic = AppLocalizations.isArabic;
    final slot = t.slotLabel(isArabic);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              ),
              if (t.isOverdue)
                StatusBadge(label: context.tr('overdue_badge'), color: AppColors.error, icon: Icons.warning_amber_rounded),
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

  // ─── Acknowledge ────────────────────────────────────────────
  Widget _buildAcknowledge(QualityTaskInstance t) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 38),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(context.tr('acknowledge_hint'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── Photo ──────────────────────────────────────────────────
  Widget _buildPhoto(QualityTaskInstance t) {
    final r = t.requirements;
    final photos = t.generalPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.tr('proof_photo'), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (photos.length >= r.minPhotos ? AppColors.success : AppDomain.quality.accent).withValues(alpha: 0.10),
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                context.tr('photos_progress').replaceAll('{x}', '${photos.length}').replaceAll('{min}', '${r.minPhotos}'),
                style: AppTypography.labelSmall.copyWith(
                    color: photos.length >= r.minPhotos ? AppColors.success : AppDomain.quality.accent,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _photoGrid(photos, null),
        if (r.requireComment) ...[
          const SizedBox(height: AppSpacing.base),
          _commentField(required: true),
        ] else ...[
          const SizedBox(height: AppSpacing.base),
          _commentField(required: false),
        ],
      ],
    );
  }

  // ─── Checklist ──────────────────────────────────────────────
  Widget _buildChecklist(QualityTaskInstance t) {
    final items = t.requirements.checklistItems;
    final doneCount = items.where(_itemDone).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.tr('proof_checklist'), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (doneCount == items.length ? AppColors.success : AppDomain.quality.accent).withValues(alpha: 0.10),
                borderRadius: AppRadius.borderFull,
              ),
              child: Text('$doneCount / ${items.length}',
                  style: AppTypography.labelSmall.copyWith(
                      color: doneCount == items.length ? AppColors.success : AppDomain.quality.accent,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) => _checklistTile(t, item)),
      ],
    );
  }

  Widget _checklistTile(QualityTaskInstance t, QualityChecklistItem item) {
    final done = _itemDone(item);
    final photos = t.photosForItem(item.key);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: done ? AppColors.successLight.withValues(alpha: 0.4) : AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: done ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.requirePhoto)
                Icon(done ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
                    color: done ? AppColors.success : AppColors.textTertiary, size: 24)
              else
                GestureDetector(
                  onTap: () => setState(() {
                    if (_localChecked.contains(item.key)) {
                      _localChecked.remove(item.key);
                    } else {
                      _localChecked.add(item.key);
                    }
                  }),
                  child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: done ? AppColors.success : AppColors.textTertiary, size: 24),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(item.label,
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (item.requirePhoto)
                TextButton.icon(
                  onPressed: _busy ? null : () => _pickAndUpload(itemKey: item.key),
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: Text(context.tr('add_photo')),
                ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _photoGrid(photos, item.key),
          ],
        ],
      ),
    );
  }

  // ─── Shared bits ────────────────────────────────────────────
  Widget _photoGrid(List<QualityTaskPhoto> photos, String? itemKey) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final p in photos)
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: CachedNetworkImage(
                  imageUrl: p.url,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 84, height: 84, color: AppColors.surfaceVariant,
                    child: const Icon(Icons.broken_image, color: AppColors.textTertiary),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _busy ? null : () => _deletePhoto(p.id),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        // Add tile
        GestureDetector(
          onTap: _busy ? null : () => _pickAndUpload(itemKey: itemKey),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: Icon(Icons.add_a_photo_rounded, color: AppDomain.quality.accent),
          ),
        ),
      ],
    );
  }

  Widget _commentField({required bool required}) {
    return TextField(
      controller: _comment,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: required ? context.tr('comment_required_label') : context.tr('comment_optional'),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: const BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: const BorderSide(color: AppColors.borderLight)),
      ),
    );
  }

  Widget _buildBottom(QualityTaskInstance t) {
    final label = t.requirements.isAcknowledge ? context.tr('mark_done') : context.tr('submit_task');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: AppButton(
          label: label,
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          loading: _busy,
          onPressed: (_canSubmit && !_busy) ? _submit : null,
        ),
      ),
    );
  }
}
