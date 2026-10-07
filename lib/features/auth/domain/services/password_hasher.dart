/// Contract for hashing and verifying passwords.
abstract interface class PasswordHasher {
  String hash(String plain);

  bool verify(String plain, String hash);
}
