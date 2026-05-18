class MemberModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final DateTime joinedAt;

  const MemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.joinedAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return MemberModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: (user?['name'] ?? json['name']) as String,
      email: (user?['email'] ?? json['email']) as String,
      avatar: (user?['avatar'] ?? json['avatar']) as String?,
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'avatar': avatar,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'ADMIN';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
