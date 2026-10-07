import 'package:dart_be/features/auth/domain/usecases/login_usecase.dart';

/// HTTP request body for `POST /auth/login`.
class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});

  /// Lenient parsing: wrong types become empty strings and are reported by
  /// the use case's validation.
  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      LoginRequestDto(
        email: json['email'] is String ? json['email'] as String : '',
        password: json['password'] is String ? json['password'] as String : '',
      );

  final String email;
  final String password;

  LoginParams toParams() => (email: email, password: password);
}
