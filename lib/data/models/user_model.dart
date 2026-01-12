class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
    };
  }
}
