import 'dart:io';

/// Application configuration loaded from environment variables.
class AppConfig {
  const AppConfig({
    required this.jwtSecret,
    required this.jwtIssuer,
    required this.accessTokenTtl,
    this.databaseUrl,
  });

  factory AppConfig.fromEnvironment() {
    final env = Platform.environment;
    final secret = env['JWT_SECRET'];
    if (secret == null || secret.isEmpty) {
      stderr.writeln(
        '[WARN] JWT_SECRET is not set. Using an insecure development secret.',
      );
    }
    final databaseUrl = env['DATABASE_URL'];
    return AppConfig(
      jwtSecret: secret ?? 'dev-insecure-secret-change-me',
      jwtIssuer: env['JWT_ISSUER'] ?? 'dart_be',
      accessTokenTtl: Duration(
        minutes: int.tryParse(env['JWT_TTL_MINUTES'] ?? '') ?? 60,
      ),
      databaseUrl: (databaseUrl?.isEmpty ?? true) ? null : databaseUrl,
    );
  }

  final String jwtSecret;
  final String jwtIssuer;
  final Duration accessTokenTtl;

  /// e.g. `postgres://user:pass@localhost:5432/db?sslmode=disable`.
  /// When `null`, an in-memory user store is used.
  final String? databaseUrl;
}
