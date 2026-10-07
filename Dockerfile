# ---- Build stage ----------------------------------------------------------
FROM dart:stable AS build

RUN dart pub global activate dart_frog_cli

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
# Generate the production server, then compile it to a native binary.
RUN dart pub global run dart_frog_cli:dart_frog build \
 && cd build \
 && dart pub get \
 && dart compile exe bin/server.dart -o bin/server

# ---- Runtime stage --------------------------------------------------------
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server

EXPOSE 8080
CMD ["/app/bin/server"]
