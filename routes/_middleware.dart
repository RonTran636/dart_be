import 'package:dart_be/di/injection.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(dependencyInjection());
}
