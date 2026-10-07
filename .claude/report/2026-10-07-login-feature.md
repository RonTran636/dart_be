# Login feature: code architecture

**Date:** 2026-10-07
**Endpoint:** `POST /auth/login`
**Status:** Done. 12/12 tests pass, `dart analyze` reports no issues, and a manual curl check against the dev server returned the expected 200 and 401 responses.

---

## 1. What was built

A login endpoint that takes an email and password, checks them against stored users, and returns a signed JWT access token.

```http
POST /auth/login
Content-Type: application/json

{ "email": "demo@example.com", "password": "Password123!" }
```

```json
200 OK
{
  "access_token": "eyJhbGciOi...",
  "token_type": "Bearer",
  "expires_at": "2026-10-07T10:43:10.487Z",
  "user": { "id": "usr_1", "email": "demo@example.com", "name": "Demo User" }
}
```

| Status | When |
|---|---|
| 200 | Credentials are correct |
| 400 | Body is not a JSON object |
| 401 | Unknown email or wrong password (same message for both) |
| 403 | Account is disabled |
| 405 | Method is not POST |
| 422 | Invalid input. The response includes one error message per field |
| 500 | Unexpected error. Details are logged, not returned |

Error responses always have this shape:

```json
{ "error": { "message": "Invalid input", "fields": { "email": "Email is invalid" } } }
```

---

## 2. Folder structure

```
lib/
├── core/                                  # Shared by every feature
│   ├── config/app_config.dart             # Reads settings from environment variables
│   ├── error/app_failure.dart             # Sealed failure types
│   └── result/result.dart                 # Sealed Result<T, E>: Success or Failure
│
├── di/
│   └── injection.dart                     # Composition root: builds every concrete object
│
└── features/
    └── auth/
        ├── domain/                        # Business rules. Plain Dart, no framework
        │   ├── entities/
        │   │   ├── user.dart
        │   │   └── auth_session.dart
        │   ├── repositories/
        │   │   └── user_repository.dart   # Interface
        │   ├── services/
        │   │   ├── password_hasher.dart   # Interface
        │   │   └── token_service.dart     # Interface
        │   └── usecases/
        │       └── login_usecase.dart     # The login logic
        │
        ├── data/                          # How the interfaces are implemented
        │   ├── models/user_model.dart     # Database shape, including the password hash
        │   ├── datasources/
        │   │   └── user_data_source.dart  # Interface + in-memory implementation
        │   ├── repositories/
        │   │   └── user_repository_impl.dart
        │   └── services/
        │       ├── bcrypt_password_hasher.dart
        │       └── jwt_token_service.dart
        │
        └── presentation/                  # HTTP in and out
            ├── dto/
            │   ├── login_request_dto.dart  # JSON body → use case input
            │   └── auth_session_dto.dart   # AuthSession → JSON response
            └── handlers/
                └── login_handler.dart      # Calls the use case, maps result to HTTP

routes/                                    # Dart Frog file-based routing
├── _middleware.dart                       # Request logging + dependency injection
├── index.dart
└── auth/
    └── login.dart                         # One line: hands off to LoginHandler

test/features/auth/
├── domain/login_usecase_test.dart         # Unit tests with mocks
└── presentation/login_handler_test.dart   # Real classes, checks the JWT
```

The code is grouped **by feature first, then by layer**. Everything about authentication lives under `features/auth/`. A new feature (for example `features/orders/`) gets its own `domain/`, `data/` and `presentation/` folders and doesn't touch `auth`.

---

## 3. The layers and the dependency rule

```
          ┌──────────────────────────────────────────────┐
          │  routes/  (Dart Frog)                        │
          └───────────────────┬──────────────────────────┘
                              │ reads LoginHandler from context
          ┌───────────────────▼──────────────────────────┐
          │  PRESENTATION   LoginHandler, DTOs           │
          └───────────────────┬──────────────────────────┘
                              │ calls
          ┌───────────────────▼──────────────────────────┐
          │  DOMAIN         LoginUseCase                 │
          │                 User, AuthSession            │
          │                 UserRepository   (interface) │
          │                 PasswordHasher   (interface) │
          │                 TokenService     (interface) │
          └───────────────────▲──────────────────────────┘
                              │ implements
          ┌───────────────────┴──────────────────────────┐
          │  DATA           UserRepositoryImpl           │
          │                 InMemoryUserDataSource       │
          │                 BcryptPasswordHasher         │
          │                 JwtTokenService              │
          └──────────────────────────────────────────────┘

          di/injection.dart connects DATA implementations to DOMAIN interfaces
```

**The rule: source code dependencies point only inward, toward the domain.**

- **Domain** imports nothing from `data/`, `presentation/` or `dart_frog`. It describes *what* the app does.
- **Data** imports domain, to implement its interfaces. It describes *how* things are stored, hashed and signed.
- **Presentation** imports domain, to call use cases. It describes *how* the outside world talks to the app.
- **Only `di/injection.dart`** knows about every layer, because its job is to connect them.

Why this matters: business rules don't change when infrastructure does. Replacing the in-memory store with Postgres, bcrypt with argon2, or Dart Frog with another framework only touches the outer layers.

---

## 4. Each layer in detail

### 4.1 Core (`lib/core/`)

| File | Purpose |
|---|---|
| `result/result.dart` | `sealed class Result<T, E>` with `Success` and `Failure`. Use cases return this instead of throwing, so every outcome is visible in the type. `fold()` turns it into a single value. |
| `error/app_failure.dart` | `sealed class AppFailure` with `ValidationFailure` (carries field errors), `InvalidCredentialsFailure`, `AccountDisabledFailure` and `ServerFailure`. Because the class is `sealed`, a `switch` over it must handle every case. |
| `config/app_config.dart` | Reads `JWT_SECRET`, `JWT_ISSUER` and `JWT_TTL_MINUTES` (default 60). Prints a warning and uses a development secret if `JWT_SECRET` is missing. |

### 4.2 Domain (`features/auth/domain/`)

**Entities**
- `User`: `id`, `email`, `name`, `isActive`. It has **no password hash**, so the hash can't leak into responses or logs.
- `AuthSession`: the result of a successful login (`user`, `accessToken`, `expiresAt`).

**Interfaces (ports)**
- `UserRepository.findCredentialsByEmail(email)` returns the record `({User user, String passwordHash})`, or `null` if there's no match. The hash is returned separately from the entity, and only to the code that needs it.
- `PasswordHasher`: `hash()` and `verify()`.
- `TokenService.issueAccessToken(user)` returns `({String token, DateTime expiresAt})`.

These are declared as `abstract interface class` (Dart 3), so other code can implement them but not extend them.

**Use case: `LoginUseCase`**

```
call(email, password)
  1. Normalize email (trim, lowercase)
  2. Validate input       → ValidationFailure with per-field errors
  3. Look up user         ┐
  4. Verify password      ┴→ InvalidCredentialsFailure (same for both, so callers can't tell which emails exist)
  5. Check isActive       → AccountDisabledFailure
  6. Issue token          → Success(AuthSession)
  Any Exception           → ServerFailure
```

It has one public method, `call()`, so it can be invoked like a function: `await login(params)`. All of its dependencies are interfaces passed into the constructor.

### 4.3 Data (`features/auth/data/`)

| Class | Role |
|---|---|
| `UserModel` | The storage shape: includes `passwordHash` and has `fromJson`/`toJson` (snake_case keys). `toEntity()` turns it into a domain `User` without the hash. |
| `UserDataSource` / `InMemoryUserDataSource` | Raw storage access. The in-memory version holds a map keyed by lowercase email. **This is the class to replace with a database implementation.** |
| `UserRepositoryImpl` | Implements the domain interface. Converts models into domain types. If you add caching or a second data source later, it goes here. |
| `BcryptPasswordHasher` | bcrypt with a configurable cost (10 in the app, 4 in tests for speed). `verify` returns `false` instead of throwing when the hash is malformed. |
| `JwtTokenService` | HS256 JWT with claims `sub` (user id), `iss`, `email`, `name`, `iat` and `exp`. Takes an optional `clock` function so tests can control time. |

### 4.4 Presentation (`features/auth/presentation/`)

- `LoginRequestDto.fromJson` parses the body leniently: a missing or wrong-typed field becomes `""`, and the use case's validation then reports it with a clear message. Validation rules live in one place, the domain.
- `AuthSessionDto` is an *extension* on `AuthSession` that adds `toJson()`. The domain entity stays free of JSON code.
- `LoginHandler` is the controller. It checks the method, parses JSON, calls the use case, and maps each `AppFailure` to a status code with an exhaustive `switch`. **Adding a new failure type won't compile until it gets a status code.**

### 4.5 Routes and dependency injection

- `di/injection.dart` builds each object once, as lazily initialized top-level `final`s, which act as singletons. It exposes `dependencyInjection()`, a Dart Frog middleware that `provide`s the `LoginHandler`.
- `routes/_middleware.dart` applies `requestLogger()` and `dependencyInjection()` to every route.
- `routes/auth/login.dart` is one line: `context.read<LoginHandler>()(context)`. Routes stay thin. They only decide which URL goes to which handler.

---

## 5. A request, end to end

```
curl POST /auth/login {"email":"Demo@Example.com","password":"Password123!"}
  │
  ├─ routes/_middleware.dart     requestLogger, then provide<LoginHandler>
  ├─ routes/auth/login.dart      context.read<LoginHandler>()(context)
  ├─ LoginHandler                method == POST? parse JSON → LoginRequestDto → LoginParams
  ├─ LoginUseCase                normalize → validate
  │    ├─ UserRepositoryImpl → InMemoryUserDataSource.findByEmail("demo@example.com")
  │    │                       → UserModel → (User, passwordHash)
  │    ├─ BcryptPasswordHasher.verify(password, hash) → true
  │    ├─ user.isActive → true
  │    └─ JwtTokenService.issueAccessToken(user) → (token, expiresAt)
  │    → Success(AuthSession)
  └─ LoginHandler                result.fold → 200 + AuthSessionDto.toJson()
```

---

## 6. Tests

| File | Type | What it covers |
|---|---|---|
| `test/features/auth/domain/login_usecase_test.dart` | Unit (mocktail) | Success with email normalization; validation errors (and the repository is never called); user not found; wrong password (and no token is issued); disabled account; repository throws → `ServerFailure` |
| `test/features/auth/presentation/login_handler_test.dart` | Integration (real classes) | 200 with a JWT verified using the secret; 401; 422 with field errors; 400 for malformed JSON; 405 for GET |

Run them with `dart test`.

---

## 7. Configuration and running

| Variable | Default | Notes |
|---|---|---|
| `JWT_SECRET` | dev fallback + warning | **Must be set in every deployed environment** |
| `JWT_ISSUER` | `dart_be` | |
| `JWT_TTL_MINUTES` | `60` | |

```bash
JWT_SECRET=your-secret dart_frog dev
```

Demo account (seeded in `di/injection.dart`): `demo@example.com` / `Password123!`

**Packages added:** `bcrypt`, `dart_jsonwebtoken`, `equatable`.
**Lint changes** (`analysis_options.yaml`): turned off `one_member_abstracts` (it flags single-method interfaces, which this architecture uses on purpose) and `public_member_api_docs` (meant for published packages, not apps).

---

## 8. Known limitations and next steps

1. **Users are stored in memory.** Add a `PostgresUserDataSource implements UserDataSource` and change one line in `injection.dart`.
2. **Hard-coded demo user.** Remove it once a real data source exists.
3. **No route protection yet.** Next step: an `authGuard()` middleware that verifies the `Authorization: Bearer` header and provides the current `User`.
4. **No refresh tokens or logout.** Access tokens can't be revoked before they expire.
5. **No rate limiting on login.** Password guessing isn't throttled.

### How to add a new feature in this structure

1. Create `lib/features/<name>/domain/`: entities, repository interfaces, and one use case per action.
2. Create `data/`: models, data sources, and repository implementations.
3. Create `presentation/`: DTOs and a handler.
4. Connect them in `di/injection.dart` and provide the handler in `dependencyInjection()`.
5. Add a thin route file under `routes/`.
6. Test the use case with mocks and the handler with real classes.
