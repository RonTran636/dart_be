# Store users in PostgreSQL with Docker

**Date:** 2026-10-07
**Status:** Done and tested.
- The full stack (API + Postgres) builds and runs with `docker compose`.
- Login works against users stored in the database, including a user added with SQL.
- Data survives a database restart.
- A fresh database runs the schema and seed scripts.
- 12/12 tests pass and `dart analyze` reports no issues.

---

## 1. What changed

Users used to live in an in-memory list that reset on every restart. They are now stored in **PostgreSQL 17**, which runs in a Docker container with a named volume, so the data persists.

Thanks to the clean architecture from the login feature, **no domain or presentation code changed**. The swap happens in the data layer and the composition root:

```
                     UserRepository  (domain interface — unchanged)
                           ▲
                 UserRepositoryImpl  (unchanged)
                           │ uses
                     UserDataSource  (interface — unchanged)
                     ▲             ▲
  InMemoryUserDataSource      PostgresUserDataSource   ← NEW
  (when DATABASE_URL unset)   (when DATABASE_URL set)
                           │
              di/injection.dart picks one at startup
```

### New and changed files

```
dart_be/
├── Dockerfile                         NEW  Multi-stage build → native binary in a minimal image
├── .dockerignore                      NEW
├── docker-compose.yml                 NEW  Services: db (Postgres 17) + api
├── .env.example                       NEW  Template for settings and secrets (committed)
├── .env                               NEW  Your local copy with a random JWT_SECRET (git-ignored)
├── .gitignore                         EDIT now ignores .env
├── pubspec.yaml                       EDIT added postgres: ^3.5.19
├── db/init/
│   ├── 001_create_users.sql           NEW  pgcrypto extension + users table
│   └── 002_seed_demo_user.sql         NEW  demo@example.com / Password123!
└── lib/
    ├── core/config/app_config.dart    EDIT reads DATABASE_URL (optional)
    ├── di/injection.dart              EDIT Postgres if DATABASE_URL is set, else in-memory
    └── features/auth/data/datasources/
        └── postgres_user_data_source.dart  NEW
```

---

## 2. How each piece works

### 2.1 Database schema (`db/init/001_create_users.sql`)

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT NOT NULL UNIQUE CHECK (email = lower(email)),
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,          -- bcrypt
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- Emails are **forced to lowercase** by a `CHECK` constraint, so the `UNIQUE` index can't hold two spellings of the same address. This matches the use case, which lowercases emails before looking them up.
- `pgcrypto` gives you `crypt()` and `gen_salt('bf')`. These produce bcrypt hashes that the app's `BcryptPasswordHasher` can verify, so you can create users straight from SQL.
- Postgres runs the files in `db/init/` in alphabetical order, and **only when the data volume is empty** (the first start).

### 2.2 `PostgresUserDataSource`

```dart
SELECT id::text AS id, email, name, password_hash, is_active
FROM users WHERE email = @email LIMIT 1
```

- Uses a named parameter (`@email`), so the query is safe from SQL injection.
- Casts `id::text` because the domain treats ids as strings.
- Reuses `UserModel.fromJson`, because the column names match the model's snake_case JSON keys.
- Depends on `Session`, an interface from the `postgres` package. You can pass it a `Pool` in production or a single `Connection` in tests.

### 2.3 Wiring (`di/injection.dart`)

```dart
final UserDataSource _userDataSource = switch (_config.databaseUrl) {
  final String url => PostgresUserDataSource(Pool<void>.withUrl(url)),
  null => _inMemoryUserDataSource(),   // prints a warning
};
```

- **Connection pool:** `Pool` reuses connections and reconnects on its own. This was tested: login still worked right after a `docker compose restart db`.
- **In-memory fallback:** without `DATABASE_URL`, the app still runs with the in-memory demo user, and the unit tests need no database.

### 2.4 `docker-compose.yml`

| Service | Image | Role |
|---|---|---|
| `db` | `postgres:17-alpine` | Stores data in the `pgdata` volume. Mounts `./db/init` for the first-run scripts. Has a `pg_isready` health check. Exposed on `localhost:${DB_PORT:-5432}`. |
| `api` | built from `Dockerfile` | Starts only after `db` is **healthy**. Connects to the host name `db` (Docker's internal network). Exposed on `localhost:${API_PORT:-8080}`. |

- `JWT_SECRET` is **required**. The `${JWT_SECRET:?...}` syntax makes compose refuse to start without it.
- Every other setting has a default and can be overridden in `.env`.

### 2.5 `Dockerfile`

| Stage | What happens |
|---|---|
| **Build** (`dart:stable`) | Installs `dart_frog_cli`, then runs `dart pub get` first so Docker caches dependencies. Runs `dart_frog build` to generate the production server, then `dart compile exe` to make a native binary. |
| **Runtime** (`scratch`) | Contains only the Dart runtime libraries and the binary. The image is small, has no shell, and starts fast. |

---

## 3. How to use it

### First-time setup

```bash
cp .env.example .env          # already done for you, with a random JWT_SECRET
# Edit .env if you want different passwords or ports.
```

### Option A: run everything in Docker

```bash
docker compose up -d --build          # build the API image and start db + api
docker compose ps                     # both should show "running" / "healthy"
docker compose logs -f api            # follow the API logs

curl -X POST localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"demo@example.com","password":"Password123!"}'
```

> Port 8080 is used by `dart_frog dev`. If that's running, stop it or set `API_PORT=8081` in `.env`.

### Option B: database in Docker, API on your machine (best for development, with hot reload)

```bash
docker compose up -d db
export $(grep -v '^#' .env | xargs)   # loads DATABASE_URL (localhost:5432) and JWT_SECRET
dart_frog dev
```

### Managing users

```bash
# Open a SQL shell
docker compose exec db psql -U dart_be -d dart_be

# Add a user (bcrypt hash generated by Postgres; the app can verify it)
docker compose exec db psql -U dart_be -d dart_be -c \
  "INSERT INTO users (email, name, password_hash)
   VALUES ('alice@example.com', 'Alice', crypt('Secret456!', gen_salt('bf', 10)));"

# List users
docker compose exec db psql -U dart_be -d dart_be -c \
  "SELECT id, email, name, is_active FROM users;"

# Disable an account (login then returns 403)
docker compose exec db psql -U dart_be -d dart_be -c \
  "UPDATE users SET is_active = false WHERE email = 'alice@example.com';"
```

You can also connect a GUI client (TablePlus, DBeaver, pgAdmin) to `localhost:5432` with user `dart_be`, password `dart_be` and database `dart_be`.

### Day-to-day commands

| Task | Command |
|---|---|
| Stop (keep data) | `docker compose down` |
| Rebuild after code changes | `docker compose up -d --build api` |
| **Wipe the database** and re-run the init scripts | `docker compose down -v && docker compose up -d` |
| Back up | `docker compose exec db pg_dump -U dart_be dart_be > backup.sql` |
| Restore | `docker compose exec -T db psql -U dart_be -d dart_be < backup.sql` |

> **Note:** the init scripts only run on an empty volume. If you edit `db/init/*.sql` later, either run `down -v` (this **deletes all data**) or apply the change by hand with `psql`.

---

## 4. Environment variables

| Variable | Used by | Default | Notes |
|---|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | db, api | `dart_be` | Change the password outside local development |
| `DB_PORT` | host → db | `5432` | Change it if Postgres is already installed locally |
| `API_PORT` | host → api | `8080` | |
| `DATABASE_URL` | api | built by compose; `.env` value for Option B | Unset → in-memory store |
| `JWT_SECRET` | api | **required** | `openssl rand -base64 48` |
| `JWT_ISSUER`, `JWT_TTL_MINUTES` | api | `dart_be`, `60` | |

---

## 5. Limitations and next steps

1. **Schema changes have no migration tool.** The init scripts only cover the first run. As the schema grows, add a migration runner (for example `dbmate` as a compose service, or a small Dart migrator) so changes apply to existing databases.
2. **No registration endpoint.** Users are created with SQL for now. A natural next feature is `POST /auth/register`, which needs a `UserRepository.create()` and a `RegisterUseCase` that uses `PasswordHasher.hash()`.
3. **Remove the demo seed for production:** delete `db/init/002_seed_demo_user.sql`.
4. **`updated_at` isn't maintained automatically.** Add a trigger, or set it in the repository, once updates exist.
5. **Production database:** use a managed Postgres service with `sslmode=require` in `DATABASE_URL`, plus strong credentials from a secrets manager instead of `.env`.
6. **No integration test against a real Postgres.** It could be added with a test-only compose service or `testcontainers`.
