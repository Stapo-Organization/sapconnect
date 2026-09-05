import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/presentation/widgets/loyalty_art.dart';
import '../../../loyalty/presentation/widgets/mission_card.dart';

/// The month's missions as a horizontal strip on the storefront.
///
/// It disappears entirely for a guest, for a control-group member, and for
/// anyone with nothing open — an empty rail with a title is worse than no rail,
/// and the holdout group has to see no play layer at all for the experiment to
/// mean anything.
///
/// The header carries the month's score as a ring, so the strip reads as one
/// board with four squares rather than four unrelated cards.
class MissionsStrip extends ConsumerWidget {
  const MissionsStrip({
    super.key,
    required this.missions,
    this.holdout = false,
    this.awaitingDelivery = false,
  });

  final List<Mission> missions;
  final bool holdout;

  /// An app order is in flight, so the order-driven missions say so.
  final bool awaitingDelivery;

  /// Whether this strip has anything to say. Home asks before it emits a slot,
  /// so an empty strip never costs a gap in the layout.
  static bool hasContent(LoyaltySummary? summary) =>
      summary != null &&
      summary.playsGames &&
      summary.missions.items.any((mission) => mission.isActive || mission.isDone);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    if (holdout || missions.isEmpty) return const SizedBox.shrink();

    // Unfinished first: the strip is a to-do list, not a trophy shelf.
    final ordered = [
      ...missions.where((mission) => !mission.isDone),
      ...missions.where((mission) => mission.isDone),
    ];
    final done = missions.where((m) => m.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          child: Row(
            children: [
              ProgressRing(
                value: missions.isEmpty ? 0 : done / missions.length,
                color: cs.primary,
                size: 34,
                stroke: 4,
                child: const MissionSticker(kind: 'welcome', size: 18),
              ),
              Gap.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.missionsTitle,
                      style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      l.missionsDoneOf(done, missions.length),
                      style: context.tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/family'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.actionSeeAll),
                    Icon(
                      context.isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final mission = ordered[index];
              return MissionCard(
                mission: mission,
                compact: true,
                width: 268,
                awaitingDelivery: awaitingDelivery &&
                    (mission.kind == 'welcome' || mission.kind == 'frequency'),
                onTap: () {
                  ref.read(eventsBufferProvider).track(
                        ZbEvent(
                          type: ZbEvents.loyaltyMission,
                          zone: 'home',
                          payload: {'mission_id': mission.id, 'state': mission.state},
                        ),
                      );
                  context.push('/family');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
