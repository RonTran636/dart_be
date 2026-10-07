import 'package:dart_be/features/auth/domain/entities/user.dart';

/// A user together with its stored password hash.
typedef UserCredentials = ({User user, String passwordHash});

/// Contract for user persistence, implemented in the data layer.
abstract interface class UserRepository {
  /// Returns the user and its password hash, or `null` if not found.
  Future<UserCredentials?> findCredentialsByEmail(String email);
}
