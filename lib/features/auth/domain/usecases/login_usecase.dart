import 'package:dart_be/core/error/app_failure.dart';
import 'package:dart_be/core/result/result.dart';
import 'package:dart_be/features/auth/domain/entities/auth_session.dart';
import 'package:dart_be/features/auth/domain/repositories/user_repository.dart';
import 'package:dart_be/features/auth/domain/services/password_hasher.dart';
import 'package:dart_be/features/auth/domain/services/token_service.dart';

/// Input for [LoginUseCase].
typedef LoginParams = ({String email, String password});

/// Authenticates a user by email and password and issues an access token.
class LoginUseCase {
  const LoginUseCase({
    required UserRepository userRepository,
    required PasswordHasher passwordHasher,
    required TokenService tokenService,
  }) : _userRepository = userRepository,
       _passwordHasher = passwordHasher,
       _tokenService = tokenService;

  final UserRepository _userRepository;
  final PasswordHasher _passwordHasher;
  final TokenService _tokenService;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Result<AuthSession, AppFailure>> call(LoginParams params) async {
    final email = params.email.trim().toLowerCase();
    final password = params.password;

    final errors = <String, String>{
      if (email.isEmpty)
        'email': 'Email is required'
      else if (!_emailRegex.hasMatch(email))
        'email': 'Email is invalid',
      if (password.isEmpty) 'password': 'Password is required',
    };
    if (errors.isNotEmpty) {
      return Failure(ValidationFailure('Invalid input', fields: errors));
    }

    try {
      final credentials = await _userRepository.findCredentialsByEmail(email);
      // Same failure for unknown user and wrong password to avoid user
      // enumeration.
      if (credentials == null ||
          !_passwordHasher.verify(password, credentials.passwordHash)) {
        return const Failure(InvalidCredentialsFailure());
      }
      if (!credentials.user.isActive) {
        return const Failure(AccountDisabledFailure());
      }

      final issued = _tokenService.issueAccessToken(credentials.user);
      return Success(
        AuthSession(
          user: credentials.user,
          accessToken: issued.token,
          expiresAt: issued.expiresAt,
        ),
      );
    } on Exception catch (e) {
      return Failure(ServerFailure('Login failed: $e'));
    }
  }
}
