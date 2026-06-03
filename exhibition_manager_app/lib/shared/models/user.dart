/// User model for the Exhibition Manager App
class User {
  final int id;
  final String name;
  final String email;
  final String? mobileNumber;
  final List<String> warehouseCodes;
  final String? avatarUrl;
  final List<String> roles;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.mobileNumber,
    required this.warehouseCodes,
    this.avatarUrl,
    required this.roles,
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

    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobile_number'],
      warehouseCodes: parseCodes(json['warehouse_code']),
      avatarUrl: json['avatar_url'],
      roles: parseRoles(json['roles']),
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
      };

  bool get isSuperAdmin => roles.contains('Super Admin');
  bool get isBranchManager => roles.contains('Branch Manager');
}
