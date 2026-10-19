import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import '../../data/full_count_models.dart';
import '../../data/full_count_repository.dart';
import '../pages/fc_board_page.dart';
import '../pages/fc_map_page.dart';
import 'fc_widgets.dart';

/// Entry to the full count from the «جرد سنوي» tab: the showroom map's state,
/// and either «start the full count» or «open the live board».
class FcEntryCard extends StatefulWidget {
  final String warehouseCode;
  const FcEntryCard({super.key, required this.warehouseCode});

  @override
  State<FcEntryCard> createState() => _FcEntryCardState();
}

class _FcEntryCardState extends State<FcEntryCard> {
  final _repo = FullCountRepository();
  FullCountSession? _active;
  StoreMap? _map;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Future.wait([_repo.active(), _repo.map(widget.warehouseCode)]);
    if (!mounted) return;
    setState(() {
      _active = (res[0] as Res<FullCountSession?>).data;
      _map = (res[1] as Res<StoreMap>).data;
      _loading = false;
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _start() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('fc_start_q')),
        content: Text(context.tr('fc_start_body'), style: const TextStyle(height: 1.7)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Fc.accentDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('fc_start')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await _repo.start(widget.warehouseCode);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      Fc.toast(context, r.error ?? '', error: true);
      return;
    }
    _open(FcBoardPage(sessionId: r.data!.id));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()));
    }
    final active = _active;
    final m = _map;
    final hasMap = (m?.units.isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: active != null ? Fc.accentDark : AppColors.surface,
        borderRadius: AppRadius.borderXl,
        border: active != null ? null : Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active != null ? Colors.white.withValues(alpha: 0.16) : Fc.soft,
              borderRadius: AppRadius.borderLg,
            ),
            child: Icon(Icons.fact_check_outlined, color: active != null ? Colors.white : Fc.accentDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active != null ? context.tr('fc_running') : context.tr('fc_title'),
                  style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700, color: active != null ? Colors.white : AppColors.textPrimary)),
              Text(
                active != null
                    ? context.tr('fc_running_sub')
                    : hasMap
                        ? context.tr('fc_map_summary')
                            .replaceAll('{u}', '${m!.units.length}')
                            .replaceAll('{s}', '${m.shelves}')
                            .replaceAll('{l}', '${m.labeled}')
                        : context.tr('fc_no_map'),
                style: AppTypography.bodySmall.copyWith(
                    color: active != null ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary, height: 1.5),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (active != null)
          AppButton(
            label: context.tr('fc_open_board'),
            icon: Icons.dashboard_outlined,
            color: Colors.white,
            variant: AppButtonVariant.tonal,
            onPressed: () => _open(FcBoardPage(sessionId: active.id)),
          )
        else
          Row(children: [
            Expanded(
              child: AppButton(
                label: context.tr('fc_map_title'),
                icon: Icons.map_outlined,
                color: Fc.accentDark,
                variant: AppButtonVariant.tonal,
                onPressed: () => _open(FcMapPage(warehouseCode: widget.warehouseCode)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: context.tr('fc_start'),
                icon: Icons.play_arrow_rounded,
                color: Fc.accentDark,
                loading: _busy,
                onPressed: hasMap ? _start : null,
              ),
            ),
          ]),
      ]),
    );
  }
}
