import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

import 'notifications_repository.dart';

/// معالِج رسائل الخلفية — يجب أن يكون دالة عُليا (top-level) ومُعلَّمة vm:entry-point.
/// رسائل نوع notification يعرضها النظام تلقائياً؛ هنا للمعالجة الصامتة فقط.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // لا حاجة لعمل شيء الآن — النظام يعرض الإشعار.
}

/// خدمة الإشعارات (FCM) — تهيئة، أذونات، دورة حياة التوكِن، عرض foreground،
/// وتوجيه النقر. نمط singleton مثل ApiClient/AppSession.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final NotificationsRepository _repo = NotificationsRepository();

  /// مفتاح Navigator عام حتى يتمكّن النقر من التوجيه دون BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;

  /// نوع الإشعار المنقور بانتظار التوجيه. يستمع له MainShell (يعمل للإقلاع
  /// البارد وللعودة من الخلفية) ويستهلكه عبر consumePendingType().
  final ValueNotifier<String?> pendingType = ValueNotifier<String?>(null);

  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
        'high_importance_channel',
        AppLocalizations.translate('notif_channel_name'),
        description: AppLocalizations.translate('notif_channel_description'),
        importance: Importance.high,
      );

  /// تُستدعى مرة في main() بعد Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // نطلب الإذن عبر FirebaseMessaging
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) => _stashType(resp.payload),
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS: إظهار الإشعار وهو بالمقدّمة.
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // foreground → اعرض banner عبر الإشعارات المحلية.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // النقر من الخلفية، ومن الإقلاع البارد.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _stashType(_typeOf(m)));
    final initial = await _fm.getInitialMessage();
    if (initial != null) _stashType(_typeOf(initial));

    // تدوير التوكِن → إعادة التسجيل.
    _fm.onTokenRefresh.listen((token) {
      _repo.registerDeviceToken(token, _platform());
    });
  }

  /// طلب الإذن + تسجيل توكِن الجهاز مع الباكند.
  /// تُستدعى بعد الدخول واستعادة الجلسة (توكِن المصادقة مضبوط في ApiClient).
  Future<void> registerToken() async {
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);

      // iOS: تأكّد من توفّر توكِن APNs قبل طلب توكِن FCM.
      if (Platform.isIOS) {
        await _fm.getAPNSToken();
      }

      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        await _repo.registerDeviceToken(token, _platform());
      }
    } catch (e) {
      debugPrint('PushService.registerToken failed: $e');
    }
  }

  /// إلغاء تسجيل الجهاز بالباكند ثم حذف التوكِن محلياً.
  /// تُستدعى قبل مسح توكِن المصادقة عند الخروج.
  Future<void> unregisterToken() async {
    try {
      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        await _repo.unregisterDeviceToken(token);
      }
      await _fm.deleteToken();
    } catch (e) {
      debugPrint('PushService.unregisterToken failed: $e');
    }
  }

  /// يستهلك نوع الإشعار المعلّق (يُضبط عند فتح التطبيق بنقرة). يُمسح بعد القراءة.
  String? consumePendingType() {
    final t = pendingType.value;
    if (t != null) pendingType.value = null;
    return t;
  }

  // ── داخلي ──────────────────────────────────────────────────
  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return; // data-only: لا شيء لعرضه
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _typeOf(message),
    );
  }

  String? _typeOf(RemoteMessage message) {
    final t = message.data['type'];
    return (t is String && t.isNotEmpty) ? t : null;
  }

  void _stashType(String? type) {
    if (type != null && type.isNotEmpty) pendingType.value = type;
  }

  String _platform() => Platform.isIOS ? 'ios' : 'android';
}
