import 'package:dart_be/features/auth/domain/entities/user.dart';

/// A signed token and its expiry.
typedef IssuedToken = ({String token, DateTime expiresAt});

/// Contract for issuing access tokens.
abstract interface class TokenService {
  IssuedToken issueAccessToken(User user);
}
