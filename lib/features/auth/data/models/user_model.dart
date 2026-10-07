import 'package:dart_be/features/auth/domain/entities/user.dart';

/// Persistence representation of a user, including the password hash.
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.passwordHash,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    passwordHash: json['password_hash'] as String,
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String email;
  final String name;
  final String passwordHash;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'password_hash': passwordHash,
    'is_active': isActive,
  };

  User toEntity() => User(id: id, email: email, name: name, isActive: isActive);
}
