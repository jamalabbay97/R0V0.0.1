sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? error) failure,
  }) {
    final self = this;
    if (self is Success<T>) {
      return success(self.data);
    }
    final fail = self as Failure<T>;
    return failure(fail.message, fail.error);
  }
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.message, {this.error});
  final String message;
  final Object? error;
}
