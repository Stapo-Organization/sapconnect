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

  /// Shows the OS prompt. Returns whether permission is now granted.
  static Future<bool> request() async {
    try {
      return await _channel.invokeMethod<bool>('request') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// `granted` | `denied` | `undetermined`.
  static Future<String> status() async {
    try {
      return await _channel.invokeMethod<String>('status') ?? 'undetermined';
    } on MissingPluginException {
      return 'undetermined';
    } on PlatformException {
      return 'undetermined';
    }
  }
}
