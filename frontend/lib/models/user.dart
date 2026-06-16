class User {
  final int id;
  final String phone;
  final String? name;
  final String role;
  final String status;
  final String? avatar;
  final String? token;
  final String? refreshToken;

  User({
    required this.id,
    required this.phone,
    this.name,
    required this.role,
    required this.status,
    this.avatar,
    this.token,
    this.refreshToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'] ?? '',
      name: json['name'],
      role: json['role'] ?? 'worker',
      status: json['status'] ?? 'ACTIVE',
      avatar: json['avatar'],
      token: json['token'],
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'status': status,
        'avatar': avatar,
      };
}
