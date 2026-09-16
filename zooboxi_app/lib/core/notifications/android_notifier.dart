import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/theme/zooboxi_tokens.dart';

/// Android draws its own notifications.
///
/// iOS shows a push exactly as the store wrote it, with the app icon beside
/// it. Android would too, but only while the app is not on screen, and only
/// with a grey disc where the logo should be — the OS composes the banner and
/// leaves the app no say. So the store sends Android a *data* message and
/// this class composes the banner: the smiling box as the status-bar glyph,
/// the full-colour mark inside, the brand teal, a channel per kind of news,
/// and the same route the store put in the payload. Foreground or background,
/// the same banner.
abstract final class AndroidNotifier {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Channels are what a customer sees under «الإشعارات» in Android's own
  /// settings, so they are named for what they carry, not for us.
  static const AndroidNotificationChannel _orders = AndroidNotificationChannel(
    'orders',
    'تحديثات الطلبات',
    description: 'حالة طلبك: التجهيز، الانطلاق، الوصول',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _offers = AndroidNotificationChannel(
    'offers',
    'العروض والمكافآت',
    description: 'عروض، بكجات، ونقاط عائلة زوبوكسي',
    importance: Importance.defaultImportance,
  );
  static const AndroidNotificationChannel _general = AndroidNotificationChannel(
    'general',
    'عام',
    description: 'تنبيهات أخرى من زوبوكسي',
    importance: Importance.defaultImportance,
  );

  /// Brings the plugin up once; safe to call from the background isolate,
  /// where nothing else of the app exists.
  static Future<void> init({void Function(String payload)? onTap}) async {
    if (!_android || _ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap?.call(payload);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in [_orders, _offers, _general]) {
      await android?.createNotificationChannel(channel);
    }
    _ready = true;
  }

  /// The payload of the notification that started the app, if one did.
  static Future<String?> launchPayload() async {
    if (!_android) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  /// Composes the banner for a data message from the store. A message with
  /// nothing to say (no title and no body) is not shown.
  static Future<void> show(RemoteMessage message) async {
    if (!_android) return;
    final data = message.data;
    final title = (data['title'] ?? message.notification?.title ?? '').toString();
    final body = (data['body'] ?? message.notification?.body ?? '').toString();
    if (title.isEmpty && body.isEmpty) return;

    await init();
    final topic = (data['topic'] ?? '').toString();
    final channel = switch (topic) {
      'orders' || 'order' || 'delivery' => _orders,
      'offers' || 'marketing' || 'campaign' || 'bundle' || 'loyalty' => _offers,
      _ => _general,
    };
    final payload = jsonEncode({
      'route': data['route'],
      'msg': data['msg'],
    });
    final collapse = (data['collapse'] ?? '').toString();

    await _plugin.show(
      // A newer status replaces the older one instead of stacking.
      id: collapse.isNotEmpty ? collapse.hashCode & 0x7fffffff : DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title.isEmpty ? null : title,
      body: body.isEmpty ? null : body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel == _orders ? Priority.high : Priority.defaultPriority,
          icon: 'ic_notification',
          largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
          color: ZbTokens.logoTeal,
          styleInformation: BigTextStyleInformation(body),
          ticker: title,
        ),
      ),
      payload: payload,
    );
  }
}

/// The background entry point: Firebase wakes a fresh isolate for a data
/// message while the app is not running, and this is all that runs in it.
@pragma('vm:entry-point')
Future<void> zooboxiBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await AndroidNotifier.show(message);
  } catch (_) {
    // A banner that could not be drawn is a missed notification, not a crash.
  }
}
