import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/campaign_countdown.dart';

/// The urgency rule, pinned. A countdown that ticks a week out is noise; one
/// that keeps counting after the campaign ended is a lie; and a deadline of
/// "2 days" must never round up from two and a half.
void main() {
  final now = DateTime(2026, 8, 26, 12);

  CampaignCountdown at(Duration remaining) =>
      CampaignCountdown.of(now.add(remaining), now: now);

  group('mode', () {
    test('no deadline says nothing', () {
      expect(CampaignCountdown.of(null, now: now).mode, CountdownMode.none);
    });

    test('an ended campaign says nothing', () {
      expect(at(const Duration(seconds: -1)).mode, CountdownMode.none);
      expect(at(Duration.zero).mode, CountdownMode.none);
    });

    test('exactly 48 hours still ticks', () {
      expect(at(const Duration(hours: 48)).mode, CountdownMode.live);
      expect(at(const Duration(hours: 47, minutes: 59)).mode, CountdownMode.live);
    });

    test('a second past 48 hours switches to whole days', () {
      final justOver = at(const Duration(hours: 48, seconds: 1));
      expect(justOver.mode, CountdownMode.days);
      expect(justOver.days, 2, reason: 'floored — never round a deadline up');
    });

    test('days are floored, not rounded', () {
      expect(at(const Duration(days: 2, hours: 23)).days, 2);
      expect(at(const Duration(days: 6, hours: 23)).days, 6);
    });

    test('the horizon is seven days', () {
      expect(at(const Duration(days: 7)).mode, CountdownMode.days);
      expect(at(const Duration(days: 7)).days, 7);
      expect(at(const Duration(days: 7, seconds: 1)).mode, CountdownMode.none);
      expect(at(const Duration(days: 30)).mode, CountdownMode.none);
    });
  });

  group('format', () {
    test('pads to HH:MM:SS in Western digits', () {
      expect(
        CampaignCountdown.format(const Duration(hours: 5, minutes: 7, seconds: 9)),
        '05:07:09',
      );
    });

    test('hours accumulate past a day rather than wrapping', () {
      expect(
        CampaignCountdown.format(const Duration(hours: 39, minutes: 12, seconds: 4)),
        '39:12:04',
      );
    });

    test('drops the seconds when they cannot be shown ticking', () {
      expect(
        CampaignCountdown.format(
          const Duration(hours: 39, minutes: 12, seconds: 4),
          seconds: false,
        ),
        '39:12',
      );
    });

    test('never renders a negative clock', () {
      expect(CampaignCountdown.format(const Duration(seconds: -30)), '00:00:00');
    });
  });
}
