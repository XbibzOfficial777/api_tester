/// Domain entity representing the response received after executing an
/// [ApiRequest].
///
/// This is a *pure* DTO – it is never persisted to the database. Instead the
/// relevant fields are extracted and stored as a [RequestHistory] entry.
class ApiResponse {
  /// The numeric HTTP status code (e.g. 200, 404).
  final int? statusCode;

  /// Human-readable reason phrase (e.g. "OK").
  final String? statusMessage;

  /// Ordered list of response headers.
  final Map<String, String> headers;

  /// Decoded response body as a string.
  final String? body;

  /// Elapsed wall-clock time from request start to the first byte of the
  /// response, in milliseconds.
  final int responseTimeMs;

  /// The size of the response body in bytes.
  final int? contentLength;

  /// Optional error description when the request failed entirely
  /// (e.g. network unreachable).
  final String? error;

  const ApiResponse({
    this.statusCode,
    this.statusMessage,
    this.headers = const {},
    this.body,
    this.responseTimeMs = 0,
    this.contentLength,
    this.error,
  });

  /// Convenience getter – `true` when [error] is non-null.
  bool get isError => error != null;

  /// Convenience getter – `true` when the status code is in the 2xx range.
  bool get isSuccessful =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Creates a mutable copy with optional field overrides.
  ApiResponse copyWith({
    int? statusCode,
    String? statusMessage,
    Map<String, String>? headers,
    String? body,
    int? responseTimeMs,
    int? contentLength,
    String? error,
  }) {
    return ApiResponse(
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      contentLength: contentLength ?? this.contentLength,
      error: error ?? this.error,
    );
  }
}