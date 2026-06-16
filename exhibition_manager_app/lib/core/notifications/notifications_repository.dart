import 'package:exhibition_manager_app/core/network/api_client.dart';
import 'package:exhibition_manager_app/core/network/api_endpoints.dart';

/// تفضيل قناة لتنبيه واحد (بريد / تطبيق) كما يصل من الـ API.
class NotificationPref {
  final String eventKey;
  final String label;
  final String labelEn;
  final String group;
  bool email;
  bool push;

  NotificationPref({
    required this.eventKey,
    required this.label,
    required this.labelEn,
    required this.group,
    required this.email,
    required this.push,
  });

  factory NotificationPref.fromJson(Map<String, dynamic> json) => NotificationPref(
        eventKey: json['event_key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        labelEn: json['label_en']?.toString() ?? '',
        group: json['group']?.toString() ?? '',
        email: json['email'] == true,
        push: json['push'] == true,
      );

  Map<String, dynamic> toPayload() => {
        'event_key': eventKey,
        'email': email,
        'push': push,
      };
}

/// يلفّ نقاط الإشعارات في الـ API: تسجيل/إلغاء توكِن الجهاز + قراءة/تحديث التفضيلات.
class NotificationsRepository {
  final ApiClient _api = ApiClient();

  /// تسجيل/تحديث توكِن هذا الجهاز للـ Push.
  Future<bool> registerDeviceToken(String token, String platform) async {
    final res = await _api.put(ApiEndpoints.fcmToken, body: {
      'token': token,
      'platform': platform,
    });
    return res.isSuccess;
  }

  /// إلغاء تسجيل توكِن الجهاز (عند الخروج / تدوير التوكِن).
  /// يُرسل التوكِن كـ query param لأن DELETE لا يحمل body في ApiClient،
  /// وLaravelValidator يقرأ من الـ input (يشمل query).
  Future<bool> unregisterDeviceToken(String token) async {
    final res = await _api.delete(
      '${ApiEndpoints.fcmToken}?token=${Uri.encodeComponent(token)}',
    );
    return res.isSuccess;
  }

  /// تفضيلات القنوات الحالية لهذا المستخدم (مُصفّاة حسب جمهوره).
  Future<List<NotificationPref>> getPreferences() async {
    final res = await _api.get(ApiEndpoints.notificationPreferences);
    if (res.isSuccess) {
      final list = (res.data['data'] as List?) ?? const [];
      return list
          .map((e) => NotificationPref.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// حفظ تفضيلات القنوات.
  Future<bool> updatePreferences(List<NotificationPref> prefs) async {
    final res = await _api.put(ApiEndpoints.notificationPreferences, body: {
      'preferences': prefs.map((p) => p.toPayload()).toList(),
    });
    return res.isSuccess;
  }
}
