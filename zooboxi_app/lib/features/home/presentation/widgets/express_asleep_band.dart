import 'package:flutter/material.dart';

import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/characters/characters.dart';
import '../../../../core/characters/companion.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// «إكسبريس نايم الحين» — the customer asked for إكسبريس, the branch is shut,
/// and the store is serving زوبكسي in its place.
///
/// Without this the page silently becomes a different shop. With it, the
/// change is said once, kindly: the animal is asleep on top of the card, the
/// card says when إكسبريس wakes, and the shelf below is the open one.
class ExpressAsleepBand extends StatelessWidget {
  const ExpressAsleepBand({super.key, required this.hours, this.now});

  final ExpressHours hours;
  final DateTime? now;

  /// Whether to show it: an إكسبريس request answered as the full store while
  /// the branch keeps hours and is shut. Out of the express zone there are no
  /// hours, and nothing to wake up from.
  static bool applies({required bool askedExpress, required CatalogScope? scope, DateTime? now}) {
    final hours = scope?.expressHours;
    if (!askedExpress || scope == null || hours == null) return false;
    if (scope.shelf == 'express') return false;
    return !isExpressOpen(now ?? DateTime.now(), hours);
  }

  static const double _sleeper = 64;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final at = now ?? DateTime.now();
    var wake = timeOfDayToday(hours.openMinutes, now: at);
    if (!wake.isAfter(at)) wake = wake.add(const Duration(days: 1));
    const cream = ZbTokens.cream;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: _sleeper - 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: ZbTokens.tealDeep,
              borderRadius: BorderRadius.circular(ZbTokens.rXl),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (dx, dy, size, alpha) in _stars)
                  PositionedDirectional(
                    end: dx,
                    top: dy,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: cream.withValues(alpha: alpha)),
                    ),
                  ),
                const PositionedDirectional(
                  end: 0,
                  top: -6,
                  child: Icon(Icons.nightlight_round, size: 28, color: ZbTokens.amber),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 40),
                      child: Text(
                        l.expressAsleepTitle,
                        style: const TextStyle(color: cream, fontSize: 20, fontWeight: FontWeight.w900, height: 1.25),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.expressAsleepBody(Fmt.clockShort(wake, locale)),
                      style: TextStyle(color: cream.withValues(alpha: 0.82), fontSize: 13.5, height: 1.45),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Asleep on the card's top edge, at the far end from the words.
          const PositionedDirectional(
            end: 70,
            top: -_sleeper + 14,
            child: Companion(ZbPose.sleep, height: _sleeper, idle: ZbIdle.sleep),
          ),
        ],
      ),
    );
  }

  static const List<(double, double, double, double)> _stars = [
    (70, 4, 3.5, 0.6),
    (104, 26, 2.5, 0.45),
    (150, 2, 3, 0.55),
    (190, 30, 2.5, 0.4),
    (48, 40, 2.5, 0.35),
  ];
}
