import 'package:dart_be/features/auth/domain/entities/user.dart';
import 'package:equatable/equatable.dart';

/// Result of a successful authentication.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
  });

  final User user;
  final String accessToken;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [user, accessToken, expiresAt];
}
