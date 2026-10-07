import 'dart:io';

import 'package:dart_be/core/config/app_config.dart';
import 'package:dart_be/features/auth/data/datasources/postgres_user_data_source.dart';
import 'package:dart_be/features/auth/data/datasources/user_data_source.dart';
import 'package:dart_be/features/auth/data/models/user_model.dart';
import 'package:dart_be/features/auth/data/repositories/user_repository_impl.dart';
import 'package:dart_be/features/auth/data/services/bcrypt_password_hasher.dart';
import 'package:dart_be/features/auth/data/services/jwt_token_service.dart';
import 'package:dart_be/features/auth/domain/repositories/user_repository.dart';
import 'package:dart_be/features/auth/domain/services/password_hasher.dart';
import 'package:dart_be/features/auth/domain/services/token_service.dart';
import 'package:dart_be/features/auth/domain/usecases/login_usecase.dart';
import 'package:dart_be/features/auth/presentation/handlers/login_handler.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

/// Composition root: the only place that knows about concrete classes.
/// Singletons are created once (top-level finals are lazily initialized).
final AppConfig _config = AppConfig.fromEnvironment();

const PasswordHasher _passwordHasher = BcryptPasswordHasher();

final UserDataSource _userDataSource = switch (_config.databaseUrl) {
  final String url => PostgresUserDataSource(Pool<void>.withUrl(url)),
  null => _inMemoryUserDataSource(),
};

/// Fallback when DATABASE_URL is not set (local dev without Docker).
UserDataSource _inMemoryUserDataSource() {
  stderr.writeln('[WARN] DATABASE_URL is not set. Using in-memory users.');
  return InMemoryUserDataSource([
    // Demo account: demo@example.com / Password123!
    UserModel(
      id: 'usr_1',
      email: 'demo@example.com',
      name: 'Demo User',
      passwordHash: _passwordHasher.hash('Password123!'),
    ),
  ]);
}

final UserRepository _userRepository = UserRepositoryImpl(_userDataSource);

final TokenService _tokenService = JwtTokenService(
  secret: _config.jwtSecret,
  issuer: _config.jwtIssuer,
  ttl: _config.accessTokenTtl,
);

final LoginUseCase _loginUseCase = LoginUseCase(
  userRepository: _userRepository,
  passwordHasher: _passwordHasher,
  tokenService: _tokenService,
);

final LoginHandler _loginHandler = LoginHandler(_loginUseCase);

/// Registers dependencies on the request context.
Middleware dependencyInjection() =>
    (handler) => handler.use(provider<LoginHandler>((_) => _loginHandler));
