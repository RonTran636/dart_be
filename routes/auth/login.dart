import 'package:dart_be/features/auth/presentation/handlers/login_handler.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /auth/login
Future<Response> onRequest(RequestContext context) =>
    context.read<LoginHandler>()(context);
