import 'package:flutter/services.dart';

import '../../features/loyalty/data/loyalty_models.dart';
import 'notify_permission.dart';

/// Local notifications for the program's dated nudges — no push server.
///
/// The store computes `nudges[]` (food running out in 5 days, a subscription
/// delivery in 3, a pet's birthday next week); the app hands the future ones
/// to the OS as scheduled local notifications. On iOS this rides the same
/// `zb/notify` channel the permission prompt uses. Anywhere the channel has
/// no handler (Android today, a simulator, tests) every call resolves to a
/// quiet no-op — a reminder is never worth a crash.
abstract final class LocalNotify {
  static const MethodChannel _channel = MethodChannel('zb/notify');

  /// The maximum the OS keeps per app is 64 pending; we stay well under it.
  static const int _max = 24;

  /// Replace every scheduled program reminder with [nudges]' future items.
  ///
  /// Only runs when permission is already granted: this must never be the
  /// thing that pops the permission prompt on someone.
  static Future<void> sync(List<Nudge> nudges) async {
    try {
      if (await NotifyPermission.status() != 'granted') return;
      final now = DateTime.now();
      final future = nudges
          .where((n) => n.at.isAfter(now.add(const Duration(minutes: 5))))
          .take(_max)
          .map((n) => {
                'id': n.notificationId,
                'title': n.title,
                'body': n.body,
                'at': n.at.millisecondsSinceEpoch ~/ 1000,
                'route': n.route,
              })
          .toList();
      await _channel.invokeMethod<void>('sync', {'items': future});
    } on MissingPluginException {
      // No native side on this platform — nothing to schedule.
    } on PlatformException {
      // A refused or failed schedule is not the customer's problem.
    }
  }

  /// Drop every scheduled reminder (sign-out).
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('sync', {'items': const <Map<String, Object>>[]});
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
