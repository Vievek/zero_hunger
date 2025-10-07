class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final bool profileCompleted;
  final String? avatar;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    required this.profileCompleted,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      phone: json['phone'],
      address: json['address'],
      profileCompleted: json['profileCompleted'] ?? false,
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'profileCompleted': profileCompleted,
    };
  }

  User copyWith({
    String? name,
    String? phone,
    String? address,
    String? role,
    bool? profileCompleted,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      avatar: avatar,
    );
  }
}

class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
    );
  }
}
