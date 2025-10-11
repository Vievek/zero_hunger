class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final bool profileCompleted;
  final String? avatar;

  // Enhanced role-specific fields
  final Map<String, dynamic>? donorDetails;
  final Map<String, dynamic>? recipientDetails;
  final Map<String, dynamic>? volunteerDetails;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    required this.profileCompleted,
    this.avatar,
    this.donorDetails,
    this.recipientDetails,
    this.volunteerDetails,
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
      donorDetails: json['donorDetails'] != null
          ? Map<String, dynamic>.from(json['donorDetails'])
          : null,
      recipientDetails: json['recipientDetails'] != null
          ? Map<String, dynamic>.from(json['recipientDetails'])
          : null,
      volunteerDetails: json['volunteerDetails'] != null
          ? Map<String, dynamic>.from(json['volunteerDetails'])
          : null,
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
      'donorDetails': donorDetails,
      'recipientDetails': recipientDetails,
      'volunteerDetails': volunteerDetails,
    };
  }

  User copyWith({
    String? name,
    String? phone,
    String? address,
    String? role,
    bool? profileCompleted,
    Map<String, dynamic>? donorDetails,
    Map<String, dynamic>? recipientDetails,
    Map<String, dynamic>? volunteerDetails,
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
      donorDetails: donorDetails ?? this.donorDetails,
      recipientDetails: recipientDetails ?? this.recipientDetails,
      volunteerDetails: volunteerDetails ?? this.volunteerDetails,
    );
  }

  bool get isDonor => role == 'donor';
  bool get isRecipient => role == 'recipient';
  bool get isVolunteer => role == 'volunteer';
  bool get isAdmin => role == 'admin';
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
