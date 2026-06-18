/// @file failures.dart
/// @brief Failure classes for the functional error-handling pattern.
///
/// The application uses the **Either** pattern (typically via the `fpdart`
/// or `dartz` package) to separate business errors from data types.
/// [Failure] objects flow back from repositories through use cases to the
/// presentation layer, where they are mapped to user-visible messages.
///
/// Each subclass corresponds to one [AppException] variant so that
/// `Exception → Failure` conversion is straightforward and lossless.

import 'package:equatable/equatable.dart';

import 'exceptions.dart';

/// Base class for all domain-level failures.
///
/// Failures are immutable value objects used as the "left" type in Either
/// monads. They intentionally carry no stack-trace information — that is
/// the responsibility of the [AppException] that produced them.
///
/// Subclasses are compared by value using [Equatable] so that Riverpod
/// providers correctly detect state changes.
abstract class Failure extends Equatable {
  /// Human-readable description intended for display in the UI.
  final String message;

  /// Creates a [Failure] with the given [message].
  const Failure(this.message);

  @override
  List<Object?> get props => [message];

  @override
  bool? get stringify => true;
}

/// Factory that maps an [AppException] to the appropriate [Failure] subtype.
///
/// This is the single point of conversion between the data layer's
/// exception-based error model and the domain layer's failure model.
///
/// ```dart
/// try {
///   // ...
/// } on AppException catch (e) {
///   return Left(e.toFailure());
/// }
/// ```
extension AppExceptionToFailure on AppException {
  /// Converts this exception into its corresponding [Failure].
  Failure toFailure() {
    switch (this) {
      case ServerException():
        return ServerFailure(message, statusCode: statusCode);
      case CacheException():
        return CacheFailure(message);
      case NetworkException():
        return NetworkFailure(message);
      case PermissionException():
        return PermissionFailure(message);
      case ParseException():
        return ParseFailure(message);
    }
  }
}

/// Failure representing a server-side error (non-2xx HTTP response).
///
/// Carries an optional [statusCode] so the UI can render colour-coded
/// status badges (e.g. red for 5xx, orange for 4xx).
class ServerFailure extends Failure {
  /// HTTP status code, if available from the original response.
  final int? statusCode;

  /// Creates a [ServerFailure] with a [message] and optional [statusCode].
  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Failure representing a local cache or storage error.
///
/// Examples: SQLite corruption, shared-preferences read failure, file I/O
/// errors during export/import operations.
class CacheFailure extends Failure {
  /// Creates a [CacheFailure] with a descriptive [message].
  const CacheFailure(super.message);
}

/// Failure representing a network connectivity problem.
///
/// Includes offline states, DNS failures, connection timeouts, and socket
/// errors. The UI typically shows a prominent "no internet" banner.
class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure] with a descriptive [message].
  const NetworkFailure(super.message);
}

/// Failure representing a denied OS permission.
///
/// Maps to scenarios where the app requests access to storage, camera,
/// notifications, or other protected resources.
class PermissionFailure extends Failure {
  /// Creates a [PermissionFailure] with a descriptive [message].
  const PermissionFailure(super.message);
}

/// Failure representing a data parsing / deserialization error.
///
/// Covers JSON decode errors, XML parsing failures, and any situation
/// where the raw response body could not be converted into the expected
/// Dart model.
class ParseFailure extends Failure {
  /// Creates a [ParseFailure] with a descriptive [message].
  const ParseFailure(super.message);
}
