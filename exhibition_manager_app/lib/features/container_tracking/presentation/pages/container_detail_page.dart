import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/utils/number_format.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';

import '../../data/container_tracking_repository.dart';
import '../../data/models/container_models.dart';
import '../widgets/container_style.dart';

/// Full voyage detail for one shipment: a stateful header (lane, carrier,
/// time-to-arrival, progress), a tracking-events timeline, the current vessel,
/// ETA-change history, sibling containers, and a link to the public tracker.
class ContainerDetailPage extends StatefulWidget {
  final int id;
  final ContainerCard initial; // header shows instantly from the list payload
  const ContainerDetailPage({super.key, required this.id, required this.initial});

  @override
  State<ContainerDetailPage> createState() => _ContainerDetailPageState();
}

class _ContainerDetailPageState extends State<ContainerDetailPage> {
  final ContainerTrackingRepository _repo = ContainerTrackingRepository();
  ContainerDetail? _detail;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _detail == null;
      _hasError = false;
    });
    final r = await _repo.getDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _detail = r.data;
      _loading = false;
      _hasError = !r.success && _detail == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final card = _detail?.card ?? widget.initial;
    final color = containerStateColor(card.stateColor);
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _header(context, card, color),
              ..._content(context, color),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ContainerCard card, Color color) => GradientHeader(
        gradient: AppDomain.containerTracking.gradient,
        leading: const BackButton(color: Colors.white),
        title: card.reference,
        subtitle: card.carrier ?? card.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Text(card.originFlag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(card.originShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white70),
                  ),
                  Text(card.destinationFlag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(card.destinationShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderFull),
                  child: Text(card.remainingLabel,
                      style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('${context.tr('ct_progress')} ${pctLabel(card.progressPercent)}',
                    style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (card.progressPercent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      );

  List<Widget> _content(BuildContext context, Color color) {
    if (_loading) {
      return [const Padding(padding: EdgeInsets.all(AppSpacing.base), child: SkeletonList(itemCount: 4, cardHeight: 80))];
    }
    if (_hasError) {
      return [Padding(padding: const EdgeInsets.only(top: AppSpacing.huge), child: ErrorStateWidget(onRetry: _load))];
    }
    final d = _detail!;
    return [
      _factsCard(context, d),
      if (d.vessel != null) _vesselCard(context, d.vessel!),
      if (d.etaHistory.length > 1) _etaHistoryCard(context, d, color),
      _eventsCard(context, d, color),
      if (d.siblings.isNotEmpty) _siblingsCard(context, d),
      if (d.publicUrl != null && d.publicUrl!.isNotEmpty) _traqoButton(context, d.publicUrl!),
    ];
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GlowIconChip(
                    icon: icon,
                    color: AppDomain.containerTracking.accent,
                    size: 30,
                    iconSize: 16,
                    borderRadius: AppRadius.borderSm,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(title, style: AppTypography.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      );

  Widget _factsCard(BuildContext context, ContainerDetail d) {
    final c = d.card;
    return _sectionCard(
      title: context.tr('ct_voyage'),
      icon: Icons.route_rounded,
      child: Column(
        children: [
          _factRow(context.tr('ct_carrier'), c.carrier ?? '—'),
          _factRow(context.tr('ct_reference'), c.reference),
          _factRow(context.tr('ct_ship_date'), shortDate(c.shipDate, withYear: true)),
          _factRow(context.tr('ct_eta'), shortDate(c.eta, withYear: true)),
          _factRow('${c.numberOfContainers} ${context.tr('ct_boxes')}', c.stateLabel),
        ],
      ),
    );
  }

  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _vesselCard(BuildContext context, VesselInfo v) => _sectionCard(
        title: context.tr('ct_vessel'),
        icon: Icons.sailing_rounded,
        child: Column(
          children: [
            if (v.name != null) _factRow('⚓', v.name!),
            if (v.imo != null) _factRow('IMO', v.imo!),
            if (v.mmsi != null) _factRow('MMSI', v.mmsi!),
          ],
        ),
      );

  Widget _etaHistoryCard(BuildContext context, ContainerDetail d, Color color) => _sectionCard(
        title: '${context.tr('ct_eta_changed')} · ${d.card.etaChangeCount} ${context.tr('ct_eta_changed_times')}',
        icon: Icons.update_rounded,
        child: Column(
          children: [
            for (final e in d.etaHistory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle_rounded, size: 7, color: color),
                    const SizedBox(width: AppSpacing.sm),
                    Text(shortDate(e.eta, withYear: true),
                        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (e.date != null)
                      Text(shortDate(e.date),
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _eventsCard(BuildContext context, ContainerDetail d, Color color) => _sectionCard(
        title: context.tr('ct_events'),
        icon: Icons.timeline_rounded,
        child: d.events.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(context.tr('ct_no_events'),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              )
            : Column(
                children: [
                  for (var i = 0; i < d.events.length; i++)
                    _eventRow(d.events[i], color, isFirst: i == 0, isLast: i == d.events.length - 1),
                ],
              ),
      );

  Widget _eventRow(TrackingEvent e, Color color, {required bool isFirst, required bool isLast}) {
    final dot = e.isActual ? color : AppColors.borderLight;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail: connector line + node.
          Column(
            children: [
              Container(width: 2, height: 6, color: isFirst ? Colors.transparent : AppColors.borderLight),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: e.isActual ? dot : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: dot, width: 2),
                ),
              ),
              Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : AppColors.borderLight)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.description,
                      style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                  if (e.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text([e.location, e.country].where((s) => s.isNotEmpty).join(AppLocalizations.isArabic ? '، ' : ', '),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ],
                  if (e.date != null) ...[
                    const SizedBox(height: 2),
                    Text(shortDate(e.date, withYear: true),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _siblingsCard(BuildContext context, ContainerDetail d) => _sectionCard(
        title: context.tr('ct_siblings'),
        icon: Icons.inventory_2_outlined,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in d.siblings)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.borderFull,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 12, color: containerStateColor(_stateColorOf(s.state))),
                    const SizedBox(width: 5),
                    Text(s.reference, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      );

  String _stateColorOf(String state) => switch (state) {
        'delivered' => 'emerald',
        'overdue' => 'rose',
        'arriving' => 'amber',
        'in_transit' => 'cyan',
        _ => 'slate',
      };

  Widget _traqoButton(BuildContext context, String url) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, 0),
        child: AppButton(
          label: context.tr('ct_open_traqo'),
          icon: Icons.link_rounded,
          variant: AppButtonVariant.outline,
          color: AppDomain.containerTracking.accent,
          onPressed: () async {
            HapticFeedback.selectionClick();
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('ct_link_copied'))),
            );
          },
        ),
      );
}
