import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../controllers/container_tracking_controller.dart';
import '../widgets/container_card.dart';
import 'container_detail_page.dart';

/// Container Tracking (تتبّع الحاويات) — the owner's ocean-freight board: a
/// needs-attention hero, state-filter chips with live counts, search + sort,
/// and shipments ranked by urgency. Read-only mirror of Traqo.
class ContainerTrackingPage extends StatefulWidget {
  const ContainerTrackingPage({super.key});

  @override
  State<ContainerTrackingPage> createState() => _ContainerTrackingPageState();
}

class _ContainerTrackingPageState extends State<ContainerTrackingPage> {
  final ContainerTrackingController _c = ContainerTrackingController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _c.dispose();
    super.dispose();
  }

  static const _states = [
    ('all', 'ct_filter_all'),
    ('overdue', 'ct_filter_overdue'),
    ('arriving', 'ct_filter_arriving'),
    ('in_transit', 'ct_filter_in_transit'),
    ('pending', 'ct_filter_pending'),
    ('delivered', 'ct_filter_delivered'),
  ];

  static const _sorts = [
    ('urgency', 'ct_sort_urgency'),
    ('eta', 'ct_sort_eta'),
    ('added', 'ct_sort_added'),
  ];

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _c.setSearch(v));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            return RefreshIndicator(
              onRefresh: _c.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _hero(context),
                  _search(context),
                  _stateFilters(context),
                  _sortRow(context),
                  ..._body(context),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final s = _c.data?.summary;
    return GradientHeader(
      gradient: AppDomain.containerTracking.gradient,
      leading: const BackButton(color: Colors.white),
      title: context.tr('ct_title'),
      subtitle: context.tr('ct_subtitle'),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if ((s?.attention ?? 0) > 0)
            _heroPill(Icons.warning_amber_rounded, '${s!.attention} ${context.tr('ct_attention')}', highlight: true),
          if (s?.nearestLabel != null)
            _heroPill(Icons.anchor_rounded,
                '${context.tr('ct_nearest')} · ${s!.nearestLabel}${s.nearestLane != null ? ' · ${s.nearestLane}' : ''}'),
          _heroPill(Icons.directions_boat_rounded,
              '${s?.counts.inTransit ?? 0} ${context.tr('ct_in_transit_count')}'),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label, {bool highlight = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight ? Colors.white : Colors.white.withValues(alpha: 0.18),
          borderRadius: AppRadius.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: highlight ? AppColors.error : Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                  color: highlight ? AppColors.error : Colors.white,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                )),
          ],
        ),
      );

  Widget _search(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xs),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.tr('ct_search_hint'),
            hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _c.setSearch('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderMd,
                borderSide: BorderSide(color: AppDomain.containerTracking.accent, width: 1.5)),
          ),
        ),
      );

  Widget _stateFilters(BuildContext context) {
    final counts = _c.data?.summary.counts;
    final accent = AppDomain.containerTracking.accent;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: AppLocalizations.isArabic,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        children: [
          for (final (key, labelKey) in _states)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: PillChip(
                label: counts == null
                    ? context.tr(labelKey)
                    : '${context.tr(labelKey)} ${counts.forState(key)}',
                selected: _c.state == key,
                onTap: () => _c.setState(key),
                color: accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortRow(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
        child: Row(
          children: [
            Icon(Icons.sort_rounded, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            for (final (key, labelKey) in _sorts)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: PillChip(
                  label: context.tr(labelKey),
                  selected: _c.sort == key,
                  onTap: () => _c.setSort(key),
                  color: AppDomain.containerTracking.accent,
                ),
              ),
          ],
        ),
      );

  List<Widget> _body(BuildContext context) {
    if (_c.loading) {
      return [const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: SkeletonList(itemCount: 5, cardHeight: 140))];
    }
    if (_c.hasError) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _c.refresh))];
    }
    final list = _c.data?.containers ?? [];
    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.huge),
          child: EmptyState(icon: Icons.inventory_2_outlined, title: context.tr('ct_no_containers')),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++)
              ContainerCardTile(
                c: list[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ContainerDetailPage(id: list[i].id, initial: list[i])),
                ),
              ).animate().fadeIn(duration: 260.ms, delay: (i * 40).ms).slideY(begin: 0.10, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    ];
  }
}
