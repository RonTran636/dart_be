import 'package:dart_be/features/auth/domain/entities/user.dart';
import 'package:dart_be/features/auth/domain/services/token_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtTokenService implements TokenService {
  JwtTokenService({
    required String secret,
    required this.issuer,
    required this.ttl,
    DateTime Function()? clock,
  }) : _key = SecretKey(secret),
       _now = clock ?? DateTime.now;

  final SecretKey _key;
  final String issuer;
  final Duration ttl;
  final DateTime Function() _now;

  @override
  IssuedToken issueAccessToken(User user) {
    final expiresAt = _now().toUtc().add(ttl);
    final jwt = JWT(
      {'email': user.email, 'name': user.name},
      subject: user.id,
      issuer: issuer,
    );
    final token = jwt.sign(_key, expiresIn: ttl);
    return (token: token, expiresAt: expiresAt);
  }
}
