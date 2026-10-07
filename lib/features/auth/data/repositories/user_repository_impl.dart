import 'package:dart_be/features/auth/data/datasources/user_data_source.dart';
import 'package:dart_be/features/auth/domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl(this._dataSource);

  final UserDataSource _dataSource;

  @override
  Future<UserCredentials?> findCredentialsByEmail(String email) async {
    final model = await _dataSource.findByEmail(email);
    if (model == null) return null;
    return (user: model.toEntity(), passwordHash: model.passwordHash);
  }
}
