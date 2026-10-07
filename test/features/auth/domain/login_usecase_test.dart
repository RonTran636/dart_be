import 'package:dart_be/core/error/app_failure.dart';
import 'package:dart_be/core/result/result.dart';
import 'package:dart_be/features/auth/domain/entities/auth_session.dart';
import 'package:dart_be/features/auth/domain/entities/user.dart';
import 'package:dart_be/features/auth/domain/repositories/user_repository.dart';
import 'package:dart_be/features/auth/domain/services/password_hasher.dart';
import 'package:dart_be/features/auth/domain/services/token_service.dart';
import 'package:dart_be/features/auth/domain/usecases/login_usecase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPasswordHasher extends Mock implements PasswordHasher {}

class _MockTokenService extends Mock implements TokenService {}

void main() {
  late _MockUserRepository repository;
  late _MockPasswordHasher hasher;
  late _MockTokenService tokens;
  late LoginUseCase login;

  const user = User(id: '1', email: 'a@b.com', name: 'A');
  final expiresAt = DateTime.utc(2030);

  setUpAll(() => registerFallbackValue(user));

  setUp(() {
    repository = _MockUserRepository();
    hasher = _MockPasswordHasher();
    tokens = _MockTokenService();
    login = LoginUseCase(
      userRepository: repository,
      passwordHasher: hasher,
      tokenService: tokens,
    );
    when(
      () => tokens.issueAccessToken(any()),
    ).thenReturn((token: 'tkn', expiresAt: expiresAt));
  });

  test('returns session on valid credentials (email normalized)', () async {
    when(
      () => repository.findCredentialsByEmail('a@b.com'),
    ).thenAnswer((_) async => (user: user, passwordHash: 'h'));
    when(() => hasher.verify('secret', 'h')).thenReturn(true);

    final result = await login((email: '  A@B.com ', password: 'secret'));

    expect(
      result,
      isA<Success<AuthSession, AppFailure>>().having(
        (s) => s.value,
        'value',
        AuthSession(user: user, accessToken: 'tkn', expiresAt: expiresAt),
      ),
    );
  });

  test('returns ValidationFailure for bad input', () async {
    final result = await login((email: 'nope', password: ''));

    final failure = (result as Failure).error as ValidationFailure;
    expect(failure.fields.keys, containsAll(['email', 'password']));
    verifyNever(() => repository.findCredentialsByEmail(any()));
  });

  test('returns InvalidCredentials when user not found', () async {
    when(
      () => repository.findCredentialsByEmail(any()),
    ).thenAnswer((_) async => null);

    final result = await login((email: 'x@y.com', password: 'p'));

    expect((result as Failure).error, const InvalidCredentialsFailure());
  });

  test('returns InvalidCredentials on wrong password', () async {
    when(
      () => repository.findCredentialsByEmail(any()),
    ).thenAnswer((_) async => (user: user, passwordHash: 'h'));
    when(() => hasher.verify(any(), any())).thenReturn(false);

    final result = await login((email: 'a@b.com', password: 'wrong'));

    expect((result as Failure).error, const InvalidCredentialsFailure());
    verifyNever(() => tokens.issueAccessToken(any()));
  });

  test('returns AccountDisabled for inactive user', () async {
    const inactive = User(
      id: '1',
      email: 'a@b.com',
      name: 'A',
      isActive: false,
    );
    when(
      () => repository.findCredentialsByEmail(any()),
    ).thenAnswer((_) async => (user: inactive, passwordHash: 'h'));
    when(() => hasher.verify(any(), any())).thenReturn(true);

    final result = await login((email: 'a@b.com', password: 'p'));

    expect((result as Failure).error, const AccountDisabledFailure());
  });

  test('returns ServerFailure when repository throws', () async {
    when(
      () => repository.findCredentialsByEmail(any()),
    ).thenThrow(Exception('db down'));

    final result = await login((email: 'a@b.com', password: 'p'));

    expect((result as Failure).error, isA<ServerFailure>());
  });
}
