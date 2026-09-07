import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zooboxi_app/core/delivery/delivery_eta.dart';
import 'package:zooboxi_app/core/utils/formatters.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';

/// 09:00 → 23:00, the express branches' real schedule.
const _hours = ExpressHours(openMinutes: 9 * 60, closeMinutes: 23 * 60);

void main() {
  // In the app the localization delegates load this before the first frame;
  // a bare unit test has to ask for it.
  setUpAll(() => initializeDateFormatting());

  group('resolveExpressEta', () {
    test('mid-afternoon it is simply two and a half hours out', () {
      final eta = resolveExpressEta(
        now: DateTime(2026, 9, 6, 15, 2),
        hours: _hours,
      );
      expect(eta.at, DateTime(2026, 9, 6, 17, 35));
      expect(eta.tomorrow, isFalse);
    });

    test('the estimate is rounded up, never down', () {
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 15, 1), hours: _hours);
      expect(eta.at.minute, 35);
      expect(eta.at.isAfter(DateTime(2026, 9, 6, 15, 1).add(expressLead)), isTrue);
    });

    test('before the shutter goes up the clock starts at opening', () {
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 7, 10), hours: _hours);
      expect(eta.at, DateTime(2026, 9, 6, 11, 30));
      expect(eta.tomorrow, isFalse);
    });

    test('a late order still gets its full two and a half hours', () {
      // The store sells express until 23:00 and owes two hours from the
      // order, so an order at 22:15 honestly lands after midnight. Trimming
      // it back to closing would promise an hour the branch cannot keep.
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 22, 15), hours: _hours);
      expect(eta.at, DateTime(2026, 9, 7, 0, 45));
      expect(eta.tomorrow, isTrue);
    });

    test('the last minute that still lands today does land today', () {
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 20, 30), hours: _hours);
      expect(eta.at, DateTime(2026, 9, 6, 23, 0));
      expect(eta.tomorrow, isFalse);
    });

    test('once the shutter is down the clock starts at tomorrow\'s opening', () {
      // 23:30, a branch that works 9–23. Reading "past opening time" as "open"
      // used to answer «غدًا 2 ص» — a handover from a shut shop, printed in
      // the biggest type on the home screen.
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 23, 30), hours: _hours);
      expect(eta.at, DateTime(2026, 9, 7, 11, 30));
      expect(eta.tomorrow, isTrue);
    });

    test('a branch that keeps no schedule is bound only by the lead time', () {
      final eta = resolveExpressEta(now: DateTime(2026, 9, 6, 23, 40));
      expect(eta.at, DateTime(2026, 9, 7, 2, 10));
      expect(eta.tomorrow, isTrue);
    });

    test('an overnight branch is open in the small hours', () {
      const overnight = ExpressHours(openMinutes: 9 * 60, closeMinutes: 2 * 60);
      final eta = resolveExpressEta(
        now: DateTime(2026, 9, 6, 0, 20),
        hours: overnight,
      );
      // Open now — the tail decides that it is open, not when the order lands.
      expect(eta.at, DateTime(2026, 9, 6, 2, 50));
    });
  });

  group('ExpressHours', () {
    test('parses the server pair', () {
      final hours = ExpressHours.maybe({'open': '09:00', 'close': '23:00'});
      expect(hours, isNotNull);
      expect(hours!.openMinutes, 540);
      expect(hours.closeMinutes, 1380);
      expect(hours.overnight, isFalse);
    });

    test('rejects anything it cannot trust', () {
      expect(ExpressHours.maybe(null), isNull);
      expect(ExpressHours.maybe({'open': '9', 'close': '23:00'}), isNull);
      expect(ExpressHours.maybe({'open': '09:00', 'close': '25:00'}), isNull);
    });
  });

  group('Fmt.clock', () {
    test('a whole hour drops its zero minutes on the shop sign', () {
      final nine = DateTime(2026, 9, 6, 9);
      expect(Fmt.clockShort(nine, 'ar'), '9 ص');
      expect(Fmt.clockShort(DateTime(2026, 9, 6, 23), 'ar'), '11 م');
      expect(Fmt.clock(DateTime(2026, 9, 6, 22, 30), 'ar'), '10:30 م');
    });

    test('digits stay Western in both languages', () {
      expect(Fmt.clock(DateTime(2026, 9, 6, 22, 30), 'en'), '10:30 PM');
    });
  });

  group('resolveStandardEta — the main warehouse', () {
    // 2026-09-07 is a Monday.
    test('before one o\'clock it goes out today', () {
      final eta = resolveStandardEta(now: DateTime(2026, 9, 7, 11, 30));
      expect(eta.kind, StandardEtaKind.today);
      expect(eta.day, DateTime(2026, 9, 7));
    });

    test('one o\'clock exactly is already too late', () {
      final eta = resolveStandardEta(now: DateTime(2026, 9, 7, 13));
      expect(eta.kind, StandardEtaKind.tomorrow);
      expect(eta.day, DateTime(2026, 9, 8));
    });

    test('after the cut-off it is tomorrow', () {
      final eta = resolveStandardEta(now: DateTime(2026, 9, 7, 20, 5));
      expect(eta.kind, StandardEtaKind.tomorrow);
    });

    test('Thursday afternoon skips Friday and lands on Saturday', () {
      // 2026-09-10 is a Thursday.
      final eta = resolveStandardEta(now: DateTime(2026, 9, 10, 15));
      expect(eta.kind, StandardEtaKind.later);
      expect(eta.day, DateTime(2026, 9, 12));
      expect(eta.day.weekday, DateTime.saturday);
    });

    test('Thursday morning still goes out the same day', () {
      final eta = resolveStandardEta(now: DateTime(2026, 9, 10, 9));
      expect(eta.kind, StandardEtaKind.today);
      expect(eta.day, DateTime(2026, 9, 10));
    });

    test('Friday is a closed day at any hour', () {
      // 2026-09-11 is a Friday.
      for (final hour in [8, 12, 18]) {
        final eta = resolveStandardEta(now: DateTime(2026, 9, 11, hour));
        expect(eta.day, DateTime(2026, 9, 12), reason: 'ordered at $hour:00');
        // Saturday is the next day either way, so the customer reads «غدًا».
        expect(eta.kind, StandardEtaKind.tomorrow);
      }
    });

    test('Thursday at exactly one o\'clock is already Saturday', () {
      final eta = resolveStandardEta(now: DateTime(2026, 9, 10, 13));
      expect(eta.day, DateTime(2026, 9, 12));
      expect(eta.kind, StandardEtaKind.later);
    });

    test('Saturday morning goes out on Saturday — the skip does not overshoot', () {
      // 2026-09-12 is a Saturday.
      final eta = resolveStandardEta(now: DateTime(2026, 9, 12, 9));
      expect(eta.day, DateTime(2026, 9, 12));
      expect(eta.kind, StandardEtaKind.today);
    });

    test('the day is named the way a customer says it', () {
      expect(Fmt.weekday(DateTime(2026, 9, 12), 'ar'), 'السبت');
      expect(Fmt.weekday(DateTime(2026, 9, 12), 'en'), 'Saturday');
    });

    test('the cut-off travels from the server as "HH:MM"', () {
      final scope = CatalogScope.maybe({
        'note': 'كل ما هنا من مستودعنا الرئيسي',
        'tier': 'same_day',
        'standard_cutoff': '13:00',
      });
      expect(scope?.standardCutoffMinutes, 13 * 60);
      expect(CatalogScope.maybe({'note': 'x'})?.standardCutoffMinutes, isNull);
    });

    test('the cut-off is the server\'s to move', () {
      final eta = resolveStandardEta(
        now: DateTime(2026, 9, 7, 15),
        cutoffMinutes: 16 * 60,
      );
      expect(eta.kind, StandardEtaKind.today);
    });
  });
}
