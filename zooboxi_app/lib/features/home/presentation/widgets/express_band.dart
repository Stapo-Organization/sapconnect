import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/shelf/shelf_controller.dart';
import '../../../../core/shelf/shelf_identity.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';

/// The first thing إكسبريس says: when this arrives.
///
/// A store leads with what it sells. A delivery app leads with when it gets
/// there — that is the whole difference in feel, and it is one band. So the
/// arrival is a clock time in the largest type on the page, and the branch
/// that owes it is named underneath, because a promise with no one behind it
/// is a slogan.
///
/// A shut branch says so and still promises: «يفتح ٩:٠٠» over the first
/// delivery it can make. [resolveExpressEta] already runs the order forward to
/// the next opening, so the second line is a real time, not a shrug.
class ExpressEtaBand extends StatelessWidget {
  const ExpressEtaBand({super.key, required this.scope, this.now});

  final CatalogScope scope;

  /// Fixed by the sheet tests; the wall clock everywhere else.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final L l = L.of(context);
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime at = now ?? DateTime.now();
    final ShelfIdentity identity = ShelfIdentity.of(context, Shelf.express);

    final ExpressHours? hours = scope.expressHours;
    final bool open = isExpressOpen(at, hours);
    final ExpressEta eta = resolveExpressEta(now: at, hours: hours);
    final String clock = Fmt.clockShort(eta.at, locale);

    // Open: the arrival leads and the window explains it. Shut: the opening
    // leads, because that is the fact that decides everything else, and the
    // arrival becomes the reassurance under it.
    final String headline = open
        ? (eta.tomorrow
            ? l.heroExpressArrivesTomorrow(clock)
            : l.heroExpressArrives(clock))
        : l.shelfExpressOpensAt(
            Fmt.clockShort(timeOfDayToday(hours!.openMinutes, now: at), locale),
          );
    final String under = open
        ? [scope.expressBranch, l.heroExpressWindow]
            .where((part) => part.isNotEmpty)
            .join(' · ')
        : (eta.tomorrow ? l.etaTomorrowAt(clock) : l.etaAt(clock));

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: identity.ribbon,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          boxShadow: [
            BoxShadow(
              color: identity.accent.withValues(alpha: 0.26),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsetsDirectional.only(
          start: 14,
          end: 16,
          top: 13,
          bottom: 13,
        ),
        child: Row(
          children: [
            // A shut branch keeps the mark but loses the charge: the same
            // badge dimmed reads as "not now", where a second icon would read
            // as a different shop.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: identity.onRibbon.withValues(alpha: open ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                open ? identity.icon : Icons.schedule_rounded,
                size: 21,
                color: identity.onRibbon.withValues(alpha: open ? 1 : 0.75),
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.titleLarge?.copyWith(
                      color: identity.onRibbon,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (under.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      under,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(
                        color: identity.onRibbon.withValues(alpha: 0.86),
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
