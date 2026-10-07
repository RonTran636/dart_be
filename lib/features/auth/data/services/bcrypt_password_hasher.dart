import 'package:bcrypt/bcrypt.dart';

import 'package:dart_be/features/auth/domain/services/password_hasher.dart';

class BcryptPasswordHasher implements PasswordHasher {
  const BcryptPasswordHasher({this.logRounds = 10});

  final int logRounds;

  @override
  String hash(String plain) =>
      BCrypt.hashpw(plain, BCrypt.gensalt(logRounds: logRounds));

  @override
  bool verify(String plain, String hash) {
    try {
      return BCrypt.checkpw(plain, hash);
    } on Object {
      return false;
    }
  }
}
