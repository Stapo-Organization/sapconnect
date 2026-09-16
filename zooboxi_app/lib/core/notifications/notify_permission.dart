import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (_android) return _androidRequest();
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
    if (_android) return _androidStatus();
    try {
      return await _channel.invokeMethod<String>('status') ?? 'undetermined';
    } on MissingPluginException {
      return 'undetermined';
    } on PlatformException {
      return 'undetermined';
    }
  }

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Android has no provisional grant and no native handler of ours: the
  /// runtime permission (Android 13 and up; older versions are always
  /// granted) is asked through firebase_messaging, which owns the channel
  /// the notifications arrive on. A build without a Firebase configuration
  /// resolves to «denied» rather than throwing, like every other gap here.
  static Future<bool> _androidRequest() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _androidStatus() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => 'granted',
        AuthorizationStatus.provisional => 'provisional',
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => 'denied',
        AuthorizationStatus.notDetermined => 'undetermined',
      };
    } catch (_) {
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
