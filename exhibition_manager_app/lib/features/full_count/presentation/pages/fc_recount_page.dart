import 'package:flutter/material.dart';
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
import 'fc_count_page.dart';

/// Blind recount queue: items whose first count disagrees with the book.
/// Nobody sees the first count or the book; round 2 is never the first counter.
class FcRecountPage extends StatefulWidget {
  final int sessionId;
  const FcRecountPage({super.key, required this.sessionId});

  @override
  State<FcRecountPage> createState() => _FcRecountPageState();
}

class _FcRecountPageState extends State<FcRecountPage> {
  final _repo = FullCountRepository();
  List<RecountItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.recountQueue(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _items = r.data;
      _error = r.error;
    });
  }

  Future<void> _start(RecountItem it) async {
    if (!it.yours) {
      Fc.toast(
          context,
          it.inProgress
              ? context.tr('fc_recount_by').replaceAll('{name}', it.byName ?? '')
              : context.tr('fc_not_yours'),
          error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FcCountPage(
            sessionId: widget.sessionId, round: it.round, presetItem: it.product, recountLocations: it.locations),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final mine = items?.where((i) => i.yours).toList() ?? [];
    final others = items?.where((i) => !i.yours).toList() ?? [];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MuntajatAppBar(title: context.tr('fc_recount_title')),
      body: items == null
          ? (_error != null ? Center(child: Text(_error!)) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              color: Fc.accent,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  FcCard(
                    color: AppColors.warningLight,
                    borderColor: AppColors.warning.withValues(alpha: 0.4),
                    child: Row(children: [
                      Icon(Icons.visibility_off_outlined, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(context.tr('fc_recount_explain'),
                            style: AppTypography.bodySmall.copyWith(color: AppColors.warning, height: 1.6, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  if (items.isEmpty)
                    EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: context.tr('fc_recount_empty'),
                      subtitle: context.tr('fc_recount_empty_sub'),
                    )
                  else ...[
                    FcSectionTitle(context.tr('fc_recount_yours').replaceAll('{n}', '${mine.length}')),
                    for (final it in mine) _row(it),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      FcSectionTitle(context.tr('fc_recount_others').replaceAll('{n}', '${others.length}')),
                      for (final it in others) _row(it),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _row(RecountItem it) {
    final arabic = AppLocalizations.isArabic;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: it.yours ? 1 : 0.55,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl, side: BorderSide(color: AppColors.border)),
          child: InkWell(
            borderRadius: AppRadius.borderXl,
            onTap: () => _start(it),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                ProductThumb(url: it.product.imageUrl, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.product.name(arabic),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, height: 1.4)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _tag(it.round == 3 ? context.tr('fc_round3') : context.tr('fc_round2'),
                          it.round == 3 ? AppColors.error : AppColors.warning),
                      if (it.inProgress)
                        _tag(
                            it.yours
                                ? context.tr('fc_recount_resume')
                                : context.tr('fc_recount_by').replaceAll('{name}', it.byName ?? ''),
                            it.yours ? AppColors.info : AppColors.textSecondary),
                      for (final l in it.locations) _tag(l, Fc.accentDark, ltr: true),
                    ]),
                  ]),
                ),
                Icon(AppLocalizations.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: AppColors.textTertiary),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c, {bool ltr = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: AppRadius.borderFull),
        child: Text(t,
            textDirection: ltr ? TextDirection.ltr : null,
            style: AppTypography.labelSmall.copyWith(color: c, fontWeight: FontWeight.w700)),
      );
}
