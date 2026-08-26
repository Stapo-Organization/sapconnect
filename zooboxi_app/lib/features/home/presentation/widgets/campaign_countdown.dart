import 'package:flutter/foundation.dart';

/// What a campaign's deadline is worth saying out loud.
enum CountdownMode {
  /// Inside 48 hours: a ticking clock, because that is when it changes
  /// behaviour.
  live,

  /// Two to seven days out: a calm "3 days left".
  days,

  /// Expired, undated, or too far away to be urgency rather than noise.
  none,
}

/// Pure countdown state — no widget, no clock of its own, so the boundaries
/// are testable and the same rule holds in the hero and in a banner.
@immutable
class CampaignCountdown {
  const CampaignCountdown(this.mode, {this.remaining = Duration.zero, this.days = 0});

  final CountdownMode mode;
  final Duration remaining;

  /// Whole days left, floored. Floored on purpose: telling someone they have
  /// three days when they have two and a half is a promise we can't keep.
  final int days;

  static const CampaignCountdown none = CampaignCountdown(CountdownMode.none);

  /// Anything inside this window ticks.
  static const Duration liveWindow = Duration(hours: 48);

  /// Past this a deadline stops being urgency and starts being clutter.
  static const Duration horizon = Duration(days: 7);

  static CampaignCountdown of(DateTime? endsAt, {DateTime? now}) {
    if (endsAt == null) return none;
    final remaining = endsAt.difference(now ?? DateTime.now());
    if (remaining <= Duration.zero) return none;
    if (remaining <= liveWindow) {
      return CampaignCountdown(CountdownMode.live, remaining: remaining);
    }
    if (remaining <= horizon) {
      return CampaignCountdown(
        CountdownMode.days,
        remaining: remaining,
        days: remaining.inDays,
      );
    }
    return none;
  }

  /// `HH:MM:SS`, or `HH:MM` when [seconds] is false — which is what Reduce
  /// Motion gets, since a second-by-second flicker is exactly the kind of
  /// self-starting movement that setting asks us to stop.
  ///
  /// Hours are not wrapped into days: "39:12:04" reads as urgent in a way
  /// "1 day 15 hours" never does. Digits are Western, as everywhere else.
  static String format(Duration remaining, {bool seconds = true}) {
    final total = remaining.isNegative ? Duration.zero : remaining;
    final hours = total.inHours.toString().padLeft(2, '0');
    final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
    if (!seconds) return '$hours:$minutes';
    return '$hours:$minutes:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
