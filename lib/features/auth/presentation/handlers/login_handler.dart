import 'dart:io';

import 'package:dart_be/core/error/app_failure.dart';
import 'package:dart_be/features/auth/domain/usecases/login_usecase.dart';
import 'package:dart_be/features/auth/presentation/dto/auth_session_dto.dart';
import 'package:dart_be/features/auth/presentation/dto/login_request_dto.dart';
import 'package:dart_frog/dart_frog.dart';

/// Translates HTTP <-> use case for login. Routes stay thin and delegate here.
class LoginHandler {
  const LoginHandler(this._login);

  final LoginUseCase _login;

  Future<Response> call(RequestContext context) async {
    if (context.request.method != HttpMethod.post) {
      return Response(statusCode: HttpStatus.methodNotAllowed);
    }

    final Map<String, dynamic> body;
    try {
      body = await context.request.json() as Map<String, dynamic>;
    } on Object {
      return _error(
        HttpStatus.badRequest,
        'Request body must be a JSON object',
      );
    }

    final result = await _login(LoginRequestDto.fromJson(body).toParams());

    return result.fold(
      (session) => Response.json(body: session.toJson()),
      (failure) => switch (failure) {
        ValidationFailure(:final message, :final fields) => _error(
          HttpStatus.unprocessableEntity,
          message,
          fields: fields,
        ),
        InvalidCredentialsFailure(:final message) => _error(
          HttpStatus.unauthorized,
          message,
        ),
        AccountDisabledFailure(:final message) => _error(
          HttpStatus.forbidden,
          message,
        ),
        ServerFailure(:final message) => () {
          stderr.writeln('[ERROR] $message');
          return _error(
            HttpStatus.internalServerError,
            'Internal server error',
          );
        }(),
      },
    );
  }

  Response _error(
    int status,
    String message, {
    Map<String, String> fields = const {},
  }) => Response.json(
    statusCode: status,
    body: {
      'error': {
        'message': message,
        if (fields.isNotEmpty) 'fields': fields,
      },
    },
  );
}
