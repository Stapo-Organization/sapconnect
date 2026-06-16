import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/features/promotions/data/promotions_repository.dart';
import 'package:exhibition_manager_app/features/promotions/data/models/campaign.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/compact_promotion_card.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/promotion_card.dart'
    show campaignTypeColor, campaignTypeIcon, campaignTypeLabel;
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/reject_feedback_sheet.dart';
import 'promotion_detail_page.dart';

/// Owner-only feed of AI-suggested ad campaigns to review and approve.
class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, this.initialStatus = 'suggested'});

  final String initialStatus; // suggested | scheduled | active | ended

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final PromotionsRepository _repo = PromotionsRepository();
  static const _statuses = ['suggested', 'scheduled', 'active', 'ended'];
  // Campaign-type filter values; 'all' shows everything.
  static const _types = ['all', 'spotlight', 'clearance', 'bundle', 'new_arrival', 'express'];

  List<Campaign> _campaigns = [];
  bool _loading = true;
  bool _hasError = false;
  String _type = 'all';
  late int _index = _statuses.indexOf(widget.initialStatus).clamp(0, _statuses.length - 1);

  /// Campaigns of the active status tab, narrowed to the selected type.
  List<Campaign> get _filtered =>
      _type == 'all' ? _campaigns : _campaigns.where((c) => c.campaignType == _type).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getCampaigns(status: _statuses[_index]);
    if (mounted) {
      setState(() {
        _campaigns = res.campaigns;
        _loading = false;
        _hasError = !res.success;
      });
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  /// Quick dismiss from the feed — captures feedback then drops the card.
  Future<void> _dismiss(Campaign c) async {
    final res = await showRejectFeedback(context);
    if (res == null) return;
    final r = await _repo.reject(c.id, reason: res.reason.isEmpty ? null : res.reason, category: res.category);
    if (!mounted) return;
    if (r.success) {
      setState(() => _campaigns.removeWhere((x) => x.id == c.id));
      _snack(context.tr('promo_dismissed'), AppColors.textSecondary);
    } else {
      _snack(r.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final accent = AppDomain.promotions.accent;
    final items = _filtered;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('promotions')),
        body: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
              child: AppSegmentedControl(
                activeColor: accent,
                items: [
                  SegmentItem(context.tr('promo_tab_suggested')),
                  SegmentItem(context.tr('promo_tab_scheduled')),
                  SegmentItem(context.tr('promo_tab_active')),
                  SegmentItem(context.tr('promo_tab_ended')),
                ],
                selectedIndex: _index,
                onChanged: (i) {
                  setState(() => _index = i);
                  _load();
                },
              ),
            ),
            // Campaign-type filter (client-side over the loaded tab).
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: _types.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final type = _types[i];
                    final isAll = type == 'all';
                    return PillChip(
                      label: isAll ? context.tr('all') : campaignTypeLabel(context, type),
                      icon: isAll ? null : campaignTypeIcon(type),
                      color: isAll ? accent : campaignTypeColor(type),
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xl),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.90,
                      ),
                      itemCount: 8,
                      itemBuilder: (_, _) => const SkeletonCard(height: 180),
                    )
                  : _hasError
                      ? ErrorStateWidget(onRetry: _load)
                      : items.isEmpty
                          ? EmptyState(
                              icon: Icons.auto_awesome_rounded,
                              color: accent,
                              title: context.tr('no_promotions'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: accent,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xl),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  childAspectRatio: 0.90,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, i) => CompactPromotionCard(
                                  campaign: items[i],
                                  onDismiss: items[i].isSuggested ? () => _dismiss(items[i]) : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PromotionDetailPage(campaignId: items[i].id),
                                    ),
                                  ).then((_) => _load()),
                                )
                                    .animate()
                                    .fadeIn(duration: 260.ms, delay: (i.clamp(0, 11) * 28).ms)
                                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
