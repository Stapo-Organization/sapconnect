import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';

/// User model for the Exhibition Manager App
class User {
  final int id;
  final String name;
  final String email;
  final String? mobileNumber;
  final List<String> warehouseCodes;
  final String? avatarUrl;
  final List<String> roles;

  /// قدرات خصائص التطبيق الممنوحة (مثل "stock_transfer.view").
  /// تأتي من الباكند مدمجةً (أدوار + استثناءات المستخدم).
  final Set<String> abilities;

  /// هل أرسل الباكند مفتاح abilities أصلاً؟
  /// لو لا (باكند قديم أثناء نشر جزئي) نعتبر كل شيء مسموحاً حتى لا يُقفل المستخدم.
  final bool abilitiesProvided;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.mobileNumber,
    required this.warehouseCodes,
    this.avatarUrl,
    required this.roles,
    this.abilities = const {},
    this.abilitiesProvided = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> parseCodes(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) return [value];
      return [];
    }

    List<String> parseRoles(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    final hasAbilities = json.containsKey('abilities') && json['abilities'] != null;

    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobile_number'],
      warehouseCodes: parseCodes(json['warehouse_code']),
      avatarUrl: json['avatar_url'],
      roles: parseRoles(json['roles']),
      abilities: parseRoles(json['abilities']).toSet(),
      abilitiesProvided: hasAbilities,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'mobile_number': mobileNumber,
        'warehouse_code': warehouseCodes,
        'avatar_url': avatarUrl,
        'roles': roles,
        'abilities': abilities.toList(),
      };

  bool get isSuperAdmin => roles.contains('Super Admin');
  bool get isBranchManager => roles.contains('Branch Manager');

  /// هل يحصل هذا المستخدم على تجربة المالك (شِل «مركز القيادة» + بوابة الإدارة)؟
  ///
  /// المالك = دور **Super Admin** حصراً. القدرات تُستخدم كخطة بديلة فقط لحمولة
  /// **بلا أدوار** (دخول OTP قديم) وبشرط أن الباكند أرسل القدرات فعلاً. هذا
  /// الحارس ضروري: [can] تسمح بكل شيء حين لا تصل abilities (باكند لا ينشر نظام
  /// الصلاحيات بعد)، فلو اعتمدنا عليها لتوجّه **كل** مستخدم — ومنهم مدير الفرع —
  /// إلى واجهة المالك الفارغة.
  bool get isOwnerExperience {
    if (isSuperAdmin) return true;
    if (roles.isNotEmpty || !abilitiesProvided) return false;
    return abilities.contains(Ability.retailDashboardView) ||
        abilities.contains(Ability.qualityAdminView) ||
        abilities.contains(Ability.stockDistributionView) ||
        abilities.contains(Ability.containerTrackingView);
  }

  /// هل يملك المستخدم القدرة المحددة؟ مثال: can('stock_transfer.confirm_receive').
  /// توافق خلفي: لو الباكند لم يرسل abilities، اسمح بكل شيء.
  bool can(String ability) {
    if (!abilitiesProvided) return true;
    return abilities.contains(ability);
  }

  /// هل يستطيع رؤية الخاصية أصلاً؟ (إجراء "view" هو بوابة الوصول.)
  bool hasFeature(String featureKey) => can('$featureKey.view');
}
