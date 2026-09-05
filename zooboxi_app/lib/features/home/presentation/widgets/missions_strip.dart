import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../loyalty/data/loyalty_models.dart';
import '../../../loyalty/presentation/widgets/mission_card.dart';

/// The month's missions as a horizontal strip on the storefront.
///
/// It disappears entirely for a guest, for a control-group member, and for
/// anyone with nothing open — an empty rail with a title is worse than no rail,
/// and the holdout group has to see no play layer at all for the experiment to
/// mean anything.
class MissionsStrip extends ConsumerWidget {
  const MissionsStrip({super.key, required this.missions, this.holdout = false});

  final List<Mission> missions;
  final bool holdout;

  /// Whether this strip has anything to say. Home asks before it emits a slot,
  /// so an empty strip never costs a gap in the layout.
  static bool hasContent(LoyaltySummary? summary) =>
      summary != null &&
      summary.playsGames &&
      summary.missions.items.any((mission) => mission.isActive || mission.isDone);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    if (holdout || missions.isEmpty) return const SizedBox.shrink();

    // Unfinished first: the strip is a to-do list, not a trophy shelf.
    final ordered = [
      ...missions.where((mission) => !mission.isDone),
      ...missions.where((mission) => mission.isDone),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l.missionsTitle,
          onSeeAll: () => context.push('/family'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final mission = ordered[index];
              return MissionCard(
                mission: mission,
                compact: true,
                width: 244,
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
