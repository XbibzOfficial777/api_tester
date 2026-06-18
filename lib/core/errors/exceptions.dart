/// @file exceptions.dart
/// @brief Custom exception classes for the API Tester application.
///
/// Each exception represents a distinct failure category that can occur
/// during data operations — server communication, local cache access,
/// network connectivity, OS permissions, or data parsing. They carry a
/// human-readable [message] and an optional HTTP [statusCode] so that the
/// presentation layer can map them to user-facing error states.

/// Base interface for all application-level exceptions.
///
/// Subclasses should provide meaningful [message] strings that can be
/// displayed directly in the UI. The optional [statusCode] is propagated
/// from HTTP responses when available.
abstract class AppException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code associated with the error, if applicable.
  ///
  /// Will be `null` for errors that do not originate from an HTTP response
  /// (e.g. network disconnections, cache corruption).
  final int? statusCode;

  /// Creates an [AppException] with the given [message] and optional [statusCode].
  const AppException(this.message, {this.statusCode});

  @override
  String toString() => '$runtimeType: $message${statusCode != null ? ' (status $statusCode)' : ''}';
}

/// Exception thrown when the remote server returns an error response.
///
/// This typically wraps a non-2xx HTTP response with a status code and
/// response body that can be shown to the user.
class ServerException extends AppException {
  /// Creates a [ServerException] with a descriptive [message] and HTTP [statusCode].
  const ServerException(super.message, {super.statusCode});

  /// Convenience factory for constructing from an HTTP response.
  ///
  /// Extracts the status code and uses the raw body as the message when
  /// no more specific description is available.
  factory ServerException.fromResponse(int statusCode, String? body) {
    return ServerException(
      body?.isNotEmpty == true ? body! : 'Server returned status $statusCode',
      statusCode: statusCode,
    );
  }
}

/// Exception thrown when a local cache operation fails.
///
/// Covers failures in shared-preferences, SQLite, or any on-device storage
/// mechanism used by the application.
class CacheException extends AppException {
  /// Creates a [CacheException] with a descriptive [message].
  const CacheException(super.message, {super.statusCode});
}

/// Exception thrown when the device has no network connectivity.
///
/// This indicates that the request could not be sent because the device is
/// offline or the DNS resolution failed.
class NetworkException extends AppException {
  /// Creates a [NetworkException] with a descriptive [message].
  const NetworkException(super.message, {super.statusCode});

  /// Convenience factory for the most common case — complete offline state.
  factory NetworkException.noConnection() {
    return const NetworkException(
      'No internet connection. Please check your network settings.',
    );
  }

  /// Convenience factory for DNS resolution failures.
  factory NetworkException.dnsFailure(String host) {
    return NetworkException(
      'Unable to resolve host: $host. Please check the URL and try again.',
    );
  }

  /// Convenience factory for connection timeouts.
  factory NetworkException.timeout() {
    return const NetworkException(
      'Connection timed out. The server may be unreachable.',
    );
  }
}

/// Exception thrown when an OS-level permission is denied.
///
/// For example, file-system access for exporting response bodies, or
/// notification permissions for push alerts.
class PermissionException extends AppException {
  /// Creates a [PermissionException] with a descriptive [message].
  const PermissionException(super.message, {super.statusCode});
}

/// Exception thrown when incoming data cannot be parsed into the expected
/// Dart model.
///
/// Wraps [FormatException] or JSON decode errors with additional context
/// about what was being parsed.
class ParseException extends AppException {
  /// Creates a [ParseException] with a descriptive [message].
  const ParseException(super.message, {super.statusCode});

  /// Convenience factory for JSON decode failures.
  factory ParseException.jsonDecode(String detail) {
    return ParseException('Failed to parse JSON: $detail');
  }

  /// Convenience factory for XML decode failures.
  factory ParseException.xmlDecode(String detail) {
    return ParseException('Failed to parse XML: $detail');
  }
}
