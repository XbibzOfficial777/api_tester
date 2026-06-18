/// @file api_constants.dart
/// @brief API-related constants and test endpoint configuration.
///
/// Contains base URLs used for quick testing, default proxy settings,
/// retry policies, and any other networking-related compile-time values.

// ignore_for_file: constant_identifier_names

/// API and networking constants used across the application.
class ApiConstants {
  ApiConstants._();

  // ---------------------------------------------------------------------------
  // Test Endpoints
  // ---------------------------------------------------------------------------

  /// JSONPlaceholder base URL — a free fake REST API ideal for quick testing.
  ///
  /// Provides resources such as /posts, /comments, /users, /todos, and /photos.
  /// See https://jsonplaceholder.typicode.com for documentation.
  static const String jsonPlaceholderBaseUrl = 'https://jsonplaceholder.typicode.com';

  /// HTTPBin base URL — a testing service that echoes request data back.
  ///
  /// Useful for inspecting headers, body, query parameters, and auth. See
  /// https://httpbin.org for documentation.
  static const String httpBinBaseUrl = 'https://httpbin.org';

  /// Reqres fake API base URL — provides simulated user & resource endpoints.
  ///
  /// See https://reqres.in for documentation.
  static const String reqresBaseUrl = 'https://reqres.in';

  // ---------------------------------------------------------------------------
  // Proxy Settings
  // ---------------------------------------------------------------------------

  /// Default proxy host — empty string means "no proxy" (direct connection).
  static const String defaultProxyHost = '';

  /// Default proxy port — ignored when [defaultProxyHost] is empty.
  static const int defaultProxyPort = 8080;

  /// Whether a proxy should be enabled by default.
  static const bool defaultProxyEnabled = false;

  // ---------------------------------------------------------------------------
  // Retry Policy
  // ---------------------------------------------------------------------------

  /// Maximum number of automatic retry attempts on transient failures.
  ///
  /// Only applies to server errors (5xx) and network timeouts.
  /// A value of `3` means the original request plus up to 3 retries.
  static const int maxRetryCount = 3;

  /// Base delay in milliseconds between retry attempts.
  ///
  /// Uses exponential back-off: the delay for attempt *n* is
  /// `retryBaseDelayMs * (2 ^ (n - 1))`.
  static const int retryBaseDelayMs = 1000;

  /// Maximum allowed retry delay cap in milliseconds to prevent excessive waits.
  static const int retryMaxDelayMs = 30000;

  // ---------------------------------------------------------------------------
  // Rate-limiting Defaults
  // ---------------------------------------------------------------------------

  /// Default rate-limit delay between consecutive requests in milliseconds.
  static const int defaultRateLimitMs = 0;

  // ---------------------------------------------------------------------------
  // Chunked / Streaming Defaults
  // ---------------------------------------------------------------------------

  /// Default chunk size in bytes for streaming large responses.
  static const int defaultChunkSize = 8192;

  // ---------------------------------------------------------------------------
  // Certificate Pinning
  // ---------------------------------------------------------------------------

  /// Whether HTTPS certificate pinning is enforced by default.
  static const bool defaultCertificatePinning = false;

  /// List of allowed SHA-256 certificate hashes (empty = no pinning).
  static const List<String> certificateHashes = [];

  // ---------------------------------------------------------------------------
  // Test Endpoint Paths (convenience shortcuts)
  // ---------------------------------------------------------------------------

  /// Quick-test GET endpoint returning a single JSON post.
  static const String testGetUrl = '$jsonPlaceholderBaseUrl/posts/1';

  /// Quick-test POST endpoint that echoes back the submitted body.
  static const String testPostUrl = '$jsonPlaceholderBaseUrl/posts';

  /// Quick-test PUT endpoint for updating a resource.
  static const String testPutUrl = '$jsonPlaceholderBaseUrl/posts/1';

  /// Quick-test DELETE endpoint.
  static const String testDeleteUrl = '$jsonPlaceholderBaseUrl/posts/1';

  /// Quick-test endpoint that returns 404 for error-code testing.
  static const String testNotFoundUrl = '$jsonPlaceholderBaseUrl/nonexistent';

  /// HTTPBin endpoint that returns request headers as JSON.
  static const String testHeadersUrl = '$httpBinBaseUrl/headers';

  /// HTTPBin endpoint that returns the request body as JSON.
  static const String testBodyUrl = '$httpBinBaseUrl/post';
}
