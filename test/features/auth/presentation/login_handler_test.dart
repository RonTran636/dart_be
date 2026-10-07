import 'dart:convert';
import 'dart:io';

import 'package:dart_be/features/auth/data/datasources/user_data_source.dart';
import 'package:dart_be/features/auth/data/models/user_model.dart';
import 'package:dart_be/features/auth/data/repositories/user_repository_impl.dart';
import 'package:dart_be/features/auth/data/services/bcrypt_password_hasher.dart';
import 'package:dart_be/features/auth/data/services/jwt_token_service.dart';
import 'package:dart_be/features/auth/domain/usecases/login_usecase.dart';
import 'package:dart_be/features/auth/presentation/handlers/login_handler.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  const secret = 'test-secret';
  late LoginHandler handler;

  setUpAll(() {
    const hasher = BcryptPasswordHasher(logRounds: 4);
    handler = LoginHandler(
      LoginUseCase(
        userRepository: UserRepositoryImpl(
          InMemoryUserDataSource([
            UserModel(
              id: 'u1',
              email: 'demo@example.com',
              name: 'Demo',
              passwordHash: hasher.hash('Password123!'),
            ),
          ]),
        ),
        passwordHasher: hasher,
        tokenService: JwtTokenService(
          secret: secret,
          issuer: 'test',
          ttl: const Duration(minutes: 5),
        ),
      ),
    );
  });

  Future<Response> send(String body, {HttpMethod method = HttpMethod.post}) {
    final context = _MockRequestContext();
    when(() => context.request).thenReturn(
      Request(
        method.value,
        Uri.parse('http://localhost/auth/login'),
        body: body,
      ),
    );
    return handler(context);
  }

  test('200 with a valid, verifiable JWT', () async {
    final res = await send(
      jsonEncode({'email': 'demo@example.com', 'password': 'Password123!'}),
    );

    expect(res.statusCode, HttpStatus.ok);
    final json = await res.json() as Map<String, dynamic>;
    expect(json['token_type'], 'Bearer');
    expect((json['user'] as Map)['id'], 'u1');
    final jwt = JWT.verify(json['access_token'] as String, SecretKey(secret));
    expect(jwt.subject, 'u1');
  });

  test('401 on wrong password', () async {
    final res = await send(
      jsonEncode({'email': 'demo@example.com', 'password': 'nope'}),
    );
    expect(res.statusCode, HttpStatus.unauthorized);
  });

  test('422 on invalid input', () async {
    final res = await send(jsonEncode({'email': 'bad'}));
    expect(res.statusCode, HttpStatus.unprocessableEntity);
    final json = await res.json() as Map<String, dynamic>;
    expect((json['error'] as Map)['fields'], contains('password'));
  });

  test('400 on malformed JSON', () async {
    final res = await send('not json');
    expect(res.statusCode, HttpStatus.badRequest);
  });

  test('405 on non-POST', () async {
    final res = await send('', method: HttpMethod.get);
    expect(res.statusCode, HttpStatus.methodNotAllowed);
  });
}
