import 'package:dart_be/features/auth/data/datasources/user_data_source.dart';
import 'package:dart_be/features/auth/data/models/user_model.dart';
import 'package:postgres/postgres.dart';

/// PostgreSQL implementation of [UserDataSource].
class PostgresUserDataSource implements UserDataSource {
  const PostgresUserDataSource(this._db);

  final Session _db;

  @override
  Future<UserModel?> findByEmail(String email) async {
    final result = await _db.execute(
      Sql.named('''
        SELECT id::text AS id, email, name, password_hash, is_active
        FROM users
        WHERE email = @email
        LIMIT 1
      '''),
      parameters: {'email': email.toLowerCase()},
    );
    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first.toColumnMap());
  }
}
