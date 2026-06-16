import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Structured reject feedback (category + free text) — collected to improve the
/// ad generator. Returns null on cancel.
Future<({String? category, String reason})?> showRejectFeedback(BuildContext context) {
  return showModalBottomSheet<({String? category, String reason})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RejectFeedbackSheet(),
  );
}

class _RejectFeedbackSheet extends StatefulWidget {
  const _RejectFeedbackSheet();

  @override
  State<_RejectFeedbackSheet> createState() => _RejectFeedbackSheetState();
}

class _RejectFeedbackSheetState extends State<_RejectFeedbackSheet> {
  final _ctrl = TextEditingController();
  String? _category;

  static const _categories = [
    ('copy', 'reject_cat_copy'),
    ('design', 'reject_cat_design'),
    ('image', 'reject_cat_image'),
    ('product', 'reject_cat_product'),
    ('offer', 'reject_cat_offer'),
    ('identity', 'reject_cat_identity'),
    ('other', 'reject_cat_other'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.promotions.accent;
    return BottomSheetScaffold(
      title: context.tr('promo_reject_reason'),
      icon: Icons.cancel_rounded,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('reject_cat_prompt'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _categories.map((c) {
                final selected = _category == c.$1;
                return ChoiceChip(
                  label: Text(context.tr(c.$2)),
                  selected: selected,
                  selectedColor: accent.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _category = selected ? null : c.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: context.tr('reject_note_label'),
                hintText: context.tr('reject_note_hint'),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: context.tr('promo_reject'),
              icon: Icons.cancel_rounded,
              onPressed: () => Navigator.pop(context, (category: _category, reason: _ctrl.text.trim())),
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
