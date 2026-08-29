import 'package:firebase_auth/firebase_auth.dart';

class AuthUserModel {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final DateTime createdAt;

  /// Whether this user is on the hardcoded ad-free allowlist (stopgap ahead
  /// of a real premium subscription tier). Computed server-side.
  final bool isAdFree;

  const AuthUserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    required this.createdAt,
    this.isAdFree = false,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAdFree: json['isAdFree'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
      'isAdFree': isAdFree,
    };
  }

  factory AuthUserModel.fromFirebaseUser(User firebaseUser) {
    return AuthUserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
      avatar: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  AuthUserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatar,
    DateTime? createdAt,
    bool? isAdFree,
  }) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      isAdFree: isAdFree ?? this.isAdFree,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUserModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AuthUserModel(id: $id, email: $email, name: $name)';
}
