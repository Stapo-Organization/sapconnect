import 'package:flutter/services.dart';

/// The notification permission, asked for natively.
///
/// The app carries no permissions package — this one prompt is the whole
/// requirement, and a plugin for it would be more surface than the feature.
/// Every failure mode (no handler on Android, a channel error, a simulator)
/// resolves to "we don't have it" rather than throwing, because a refused
/// prompt and a missing platform are the same thing to the caller.
abstract final class NotifyPermission {
  static const MethodChannel _channel = MethodChannel('zb/notify');

  /// Asks the OS. Returns whether we may now send anything at all.
  ///
  /// With [provisional] iOS shows **no dialog**: notifications start arriving
  /// straight into Notification Centre, quietly, and the customer decides
  /// later — from the notification itself or from our settings screen —
  /// whether they want to be interrupted. That is the one shape of this
  /// question that cannot be answered "no" by accident, which is why the
  /// welcome journey now asks it that way and keeps the real prompt for the
  /// moment there is an order to follow.
  static Future<bool> request({bool provisional = false}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'request',
            {'provisional': provisional},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// `granted` | `provisional` | `denied` | `undetermined`.
  static Future<String> status() async {
    try {
      return await _channel.invokeMethod<String>('status') ?? 'undetermined';
    } on MissingPluginException {
      return 'undetermined';
    } on PlatformException {
      return 'undetermined';
    }
  }

  /// Whether this device can be reached at all — quietly counts.
  ///
  /// The distinction the *registration* cares about is not "may we
  /// interrupt", it is "will APNs mint a token for us", and a provisional
  /// grant does.
  static Future<bool> get isRegistered async {
    final status = await NotifyPermission.status();
    return status == 'granted' || status == 'provisional';
  }
}
