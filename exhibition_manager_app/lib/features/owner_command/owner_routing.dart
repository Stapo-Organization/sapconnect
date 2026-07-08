import 'package:flutter/material.dart';

import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/shared/models/user.dart';
import 'package:exhibition_manager_app/features/home/presentation/pages/main_shell.dart';

import 'presentation/pages/owner_shell.dart';

/// بوابة اختيار الشِل بعد الدخول: المالك → «مركز القيادة» (OwnerShell)،
/// وغيره → MainShell كما هو. تُستدعى في موضعَي ما بعد الدخول (splash + login).
class OwnerRouting {
  OwnerRouting._();

  /// يُعتبر مالكاً إذا كان Super Admin، أو (احتياطاً عند payload ناقص بلا
  /// roles مثل دخول OTP) يملك أي قدرة إدارية حصرية. نفس مجموعة قدرات
  /// MainShell._canSeeAdmin، فلا يتراجع المالك للتجربة العادية بصمت.
  static bool isOwner(User u) =>
      u.isSuperAdmin ||
      u.can(Ability.retailDashboardView) ||
      u.can(Ability.qualityAdminView) ||
      u.can(Ability.stockDistributionView) ||
      u.can(Ability.containerTrackingView);

  static Widget shellFor(User u) =>
      isOwner(u) ? OwnerShell(user: u) : MainShell(user: u);
}
