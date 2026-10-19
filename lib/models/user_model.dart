class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'player' | 'admin'
  final String? phone;
  final String? photoUrl;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.photoUrl,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'player',
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'photoUrl': photoUrl,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? phone,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
