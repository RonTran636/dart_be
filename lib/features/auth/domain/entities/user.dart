import 'package:equatable/equatable.dart';

/// Core user entity. Free of any framework or persistence concerns.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String name;
  final bool isActive;

  @override
  List<Object?> get props => [id, email, name, isActive];
}
