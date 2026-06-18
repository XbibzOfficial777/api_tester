/// @file app_constants.dart
/// @brief Application-wide constants for the API Tester app.
///
/// Contains static configuration values used across the entire application
/// including app metadata, HTTP method definitions, body type enumerations,
/// content-type mappings, default headers, and database configuration.
/// All values are compile-time constants for maximum performance.

// ignore_for_file: constant_identifier_names

/// Application-level constants.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------------
  // App Metadata
  // ---------------------------------------------------------------------------

  /// Human-readable application name displayed in titles and about screens.
  static const String appName = 'API Tester';

  /// Semantic version string following MAJOR.MINOR.PATCH convention.
  static const String appVersion = '1.0.0';

  /// Build number incremented on every release for internal tracking.
  static const int buildNumber = 1;

  /// Package identifier used by Android and iOS app stores.
  static const String packageName = 'com.api.tester';

  // ---------------------------------------------------------------------------
  // Network Defaults
  // ---------------------------------------------------------------------------

  /// Default request timeout duration in seconds.
  ///
  /// After this period the connection attempt will be aborted and a
  /// [DioException] with [DioExceptionType.connectionTimeout] is thrown.
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Maximum number of redirect follow attempts before failing.
  static const int maxRedirects = 5;

  /// Maximum size for request/response bodies in bytes (10 MB).
  static const int maxBodySize = 10 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // HTTP Methods
  // ---------------------------------------------------------------------------

  /// Supported HTTP methods the user can select when building a request.
  ///
  /// Each entry maps to a Dart string that is compatible with the `method`
  /// property of [Dio RequestOptions].
  static const List<String> httpMethods = [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
  ];

  // ---------------------------------------------------------------------------
  // Body Types
  // ---------------------------------------------------------------------------

  /// Default headers included with every outgoing request unless overridden.
  ///
  /// These represent a sensible baseline for a modern REST API client.
  /// Users can modify or remove them per-request.
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'User-Agent': 'API Tester/$appVersion',
    'Accept-Encoding': 'gzip, deflate, br',
  };

  // ---------------------------------------------------------------------------
  // Database Configuration
  // ---------------------------------------------------------------------------

  /// SQLite database file name used by Drift ORM.
  static const String databaseName = 'api_tester.db';

  /// Schema version number — must be bumped every time a migration is added.
  static const int databaseVersion = 1;

  // ---------------------------------------------------------------------------
  // UI Defaults
  // ---------------------------------------------------------------------------

  /// Maximum number of recent requests kept in the history list.
  static const int maxHistoryItems = 100;

  /// Maximum depth for JSON pretty-print formatting.
  static const int jsonIndentDepth = 2;

  /// Debounce delay for search-as-you-type inputs in milliseconds.
  static const int searchDebounceMs = 300;

  /// Maximum number of collections / folders visible without scrolling.
  static const int visibleCollectionLimit = 20;

  /// Minimum character length before enabling live search.
  static const int minSearchLength = 2;
}

/// Enumeration of request body encoding types.
///
/// Determines how the request body is serialised before being sent over the
/// network. Each value maps to a corresponding `Content-Type` header in
/// [AppConstants.contentTypes].
enum BodyType {
  /// No request body is sent (common for GET, DELETE, HEAD).
  none,

  /// `multipart/form-data` — used for file uploads and mixed key-value pairs.
  formData,

  /// `application/x-www-form-urlencoded` — traditional HTML form encoding.
  urlEncoded,

  /// `application/json` — raw text body, typically JSON but can be any text.
  raw,

  /// `application/octet-stream` — binary data such as images or archives.
  binary,
}

/// Human-readable label displayed in the UI for each [BodyType].
const Map<BodyType, String> bodyTypeLabels = {
  BodyType.none: 'None',
  BodyType.formData: 'Form Data',
  BodyType.urlEncoded: 'x-www-form-urlencoded',
  BodyType.raw: 'Raw (JSON)',
  BodyType.binary: 'Binary',
};

/// Maps each [BodyType] to the `Content-Type` header value that should be sent.
const Map<BodyType, String> contentTypes = {
  BodyType.none: '',
  BodyType.formData: 'multipart/form-data',
  BodyType.urlEncoded: 'application/x-www-form-urlencoded',
  BodyType.raw: 'application/json; charset=utf-8',
  BodyType.binary: 'application/octet-stream',
};
