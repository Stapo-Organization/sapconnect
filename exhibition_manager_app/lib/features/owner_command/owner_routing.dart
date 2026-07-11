import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/home/presentation/pages/main_shell.dart';

import 'presentation/pages/owner_shell.dart';

/// بوابة اختيار الشِل بعد الدخول: المالك → «مركز القيادة» (OwnerShell)،
/// وغيره → MainShell كما هو. تُستدعى في موضعَي ما بعد الدخول (splash + login).
class OwnerRouting {
  OwnerRouting._();

  /// مصدر الحقيقة الوحيد لتوجيه المالك: [User.isOwnerExperience] (المالك =
  /// Super Admin، مع خطة بديلة عبر القدرات لحمولة OTP بلا أدوار فقط). لا نعتمد
  /// على [User.can] هنا لأنها تسمح بكل شيء حين لا يرسل الباكند abilities.
  static bool isOwner(User u) => u.isOwnerExperience;

  static Widget shellFor(User u) =>
      isOwner(u) ? OwnerShell(user: u) : MainShell(user: u);
}
