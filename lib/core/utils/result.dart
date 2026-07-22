/// Errors-as-values. Repositories return [Result] — never throw into UI.
sealed class Result<T> {
  const Result();

  R when<R>({required R Function(T value) ok, required R Function(AppFailure f) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };

  T? get valueOrNull => switch (this) { Ok<T>(:final value) => value, _ => null };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

/// A user-presentable failure. [message] is written for humans, not logs.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($message)';
}
