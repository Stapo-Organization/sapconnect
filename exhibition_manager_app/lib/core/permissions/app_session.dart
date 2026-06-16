import 'package:exhibition_manager_app/shared/models/user.dart';

/// حامل الجلسة العام — يتيح فحص صلاحيات المستخدم الحالي من أي صفحة عميقة
/// دون تمرير كائن المستخدم عبر كل constructor.
///
/// يُعبّأ من [AuthRepository] عند تسجيل الدخول وعند استعادة الجلسة، ويُمسح عند الخروج.
class AppSession {
  AppSession._();

  static User? user;

  static void set(User u) => user = u;
  static void clear() => user = null;

  /// هل يملك المستخدم الحالي القدرة؟ توافق خلفي: قبل التحميل أو لباكند قديم → اسمح.
  static bool can(String ability) => user?.can(ability) ?? true;

  /// هل يرى الخاصية؟
  static bool hasFeature(String featureKey) => user?.hasFeature(featureKey) ?? true;
}
