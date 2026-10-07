import 'package:dart_be/features/auth/domain/entities/auth_session.dart';

/// HTTP response body for a successful login.
extension AuthSessionDto on AuthSession {
  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'token_type': 'Bearer',
    'expires_at': expiresAt.toIso8601String(),
    'user': {'id': user.id, 'email': user.email, 'name': user.name},
  };
}
