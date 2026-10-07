import 'package:equatable/equatable.dart';

/// Base type for all domain-level failures.
sealed class AppFailure extends Equatable {
  const AppFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Input did not pass validation.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fields = const {}});

  /// Field name -> error message.
  final Map<String, String> fields;

  @override
  List<Object?> get props => [message, fields];
}

/// Credentials were wrong or the user does not exist.
final class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure() : super('Invalid email or password');
}

/// The account exists but cannot log in.
final class AccountDisabledFailure extends AppFailure {
  const AccountDisabledFailure() : super('Account is disabled');
}

/// Unexpected infrastructure error.
final class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Internal server error']);
}
