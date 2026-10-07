/// A functional-style result type: either a [Success] or a [Failure].
sealed class Result<T, E> {
  const Result();

  /// Folds both branches into a single value.
  R fold<R>(R Function(T value) onSuccess, R Function(E error) onFailure) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final error) => onFailure(error),
      };
}

/// Successful result carrying [value].
final class Success<T, E> extends Result<T, E> {
  const Success(this.value);

  final T value;
}

/// Failed result carrying [error].
final class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);

  final E error;
}
