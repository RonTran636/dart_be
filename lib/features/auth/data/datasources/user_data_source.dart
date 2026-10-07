import 'package:dart_be/features/auth/data/models/user_model.dart';

/// Low-level access to user records (DB, remote API, memory...).
abstract interface class UserDataSource {
  Future<UserModel?> findByEmail(String email);
}

/// In-memory implementation. Swap for a Postgres/Mongo data source later
/// without touching the domain layer.
class InMemoryUserDataSource implements UserDataSource {
  InMemoryUserDataSource(Iterable<UserModel> seed)
    : _users = {for (final u in seed) u.email.toLowerCase(): u};

  final Map<String, UserModel> _users;

  @override
  Future<UserModel?> findByEmail(String email) async =>
      _users[email.toLowerCase()];
}
