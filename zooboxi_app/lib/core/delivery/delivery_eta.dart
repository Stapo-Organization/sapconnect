import 'package:flutter/foundation.dart';

import '../../features/catalog/data/catalog_models.dart';

/// When an express order actually lands.
///
/// The store promises two hours of delivery; the honest number a customer
/// reads on the header is that plus the half hour the branch spends picking
/// and handing over — so the app names a **clock time**, «الساعة 10:30 م»,
/// instead of a countdown that starts again every time the page repaints.
///
/// The arithmetic lives here, apart from any widget, because it has three
/// edges worth testing: before the branch opens, after it shuts, and a branch
/// that works past midnight.
const Duration expressLead = Duration(hours: 2, minutes: 30);

/// The estimate is rounded up to the next five minutes — «10:32 م» reads like
/// a tracking number, «10:35 م» reads like a promise.
const int _roundToMinutes = 5;

/// Times are read on the device's own clock against the branch's Riyadh
/// schedule. Every customer of this store is in Saudi Arabia on Saudi time, so
/// the two agree; a phone deliberately set to another zone would show its own
/// evening, which is the same thing every delivery app in the market does.

@immutable
class ExpressEta {
  const ExpressEta({required this.at, required this.tomorrow});

  /// The moment the order is expected at the door.
  final DateTime at;

  /// True when [at] falls on a later calendar day than the moment asked for —
  /// the branch had already shut, so the order rides the next opening.
  final bool tomorrow;
}

/// The arrival moment for an express order placed at [now].
///
/// [hours] is the covering branch's own schedule; null means it keeps none
/// (always open), in which case the lead time alone decides.
ExpressEta resolveExpressEta({
  required DateTime now,
  ExpressHours? hours,
  Duration lead = expressLead,
}) {
  if (hours == null) {
    return _eta(now, now.add(lead));
  }

  final midnight = DateTime(now.year, now.month, now.day);
  final open = midnight.add(Duration(minutes: hours.openMinutes));

  // Today's closing moment. On an overnight schedule this is the tail of
  // *last* night's shift, which is why it decides whether the branch is open
  // in the small hours rather than when a late order lands.
  final tail = midnight.add(Duration(minutes: hours.closeMinutes));

  // Before the shutter goes up: the clock starts when the branch does.
  //
  // After it, the lead time runs from the order and nothing shortens it — the
  // store sells express right up to closing and still owes two hours, so a
  // 22:50 order honestly lands after midnight. Trimming that back to closing
  // time would have the header promise an hour the branch cannot keep.
  final openNow = !now.isBefore(open) || (hours.overnight && !now.isAfter(tail));
  return _eta(now, openNow ? now.add(lead) : open.add(lead));
}

ExpressEta _eta(DateTime now, DateTime at) {
  final rounded = _roundUp(at);
  return ExpressEta(
    at: rounded,
    tomorrow: DateTime(rounded.year, rounded.month, rounded.day)
        .isAfter(DateTime(now.year, now.month, now.day)),
  );
}

DateTime _roundUp(DateTime t) {
  final remainder = t.minute % _roundToMinutes;
  final bump = remainder == 0 ? 0 : _roundToMinutes - remainder;
  return DateTime(t.year, t.month, t.day, t.hour, t.minute + bump);
}

/// A wall-clock time of day on today's date — for rendering opening hours.
DateTime timeOfDayToday(int minutes, {DateTime? now}) {
  final base = now ?? DateTime.now();
  return DateTime(base.year, base.month, base.day).add(Duration(minutes: minutes));
}


/// When an order from the MAIN warehouse lands — the زوبكسي storefront's
/// promise.
///
/// The owner's rule: order before the cut-off (13:00) and it goes out today;
/// after it, tomorrow. Friday is not a delivery day, so Thursday afternoon and
/// the whole of Friday land on Saturday.
///
/// The server owns the same rule and quotes it on every product chip; the app
/// recomputes it live so a payload cached at 12:55 cannot still be promising
/// "today" at 13:05.
const int standardCutoffMinutes = 13 * 60;

/// Friday, in Dart's 1=Monday…7=Sunday numbering.
const int _closedWeekday = DateTime.friday;

enum StandardEtaKind { today, tomorrow, later }

@immutable
class StandardEta {
  const StandardEta({required this.day, required this.kind});

  /// Midnight on the day the order arrives.
  final DateTime day;
  final StandardEtaKind kind;
}

StandardEta resolveStandardEta({
  required DateTime now,
  int cutoffMinutes = standardCutoffMinutes,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.add(Duration(minutes: cutoffMinutes));

  var day = now.isBefore(cutoff) ? today : today.add(const Duration(days: 1));
  while (day.weekday == _closedWeekday) {
    day = day.add(const Duration(days: 1));
  }

  final days = day.difference(today).inDays;
  return StandardEta(
    day: day,
    kind: switch (days) {
      <= 0 => StandardEtaKind.today,
      1 => StandardEtaKind.tomorrow,
      _ => StandardEtaKind.later,
    },
  );
}
