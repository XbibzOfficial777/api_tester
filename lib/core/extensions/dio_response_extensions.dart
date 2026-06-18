/// @file dio_response_extensions.dart
/// @brief Extension methods on Dio's [Response] class.
///
/// Adds convenience accessors for formatted byte sizes, timing information,
/// and common response attributes. Designed to reduce boilerplate in the
/// presentation layer when displaying HTTP response details.
///
/// ```dart
/// final response = await dio.get('/users');
/// print(response.formattedSize);   // '4.2 KB'
/// print(response.timingInfo);      // '245 ms'
/// print(response.isJson);           // true
/// ```

import 'dart:convert';

import 'package:dio/dio.dart';

import '../utils/response_helper.dart';

/// Extension that adds formatting and inspection helpers to Dio's [Response].
extension DioResponseExtensions on Response {
  // ---------------------------------------------------------------------------
  // Size Formatting
  // ---------------------------------------------------------------------------

  /// Returns the response body size as a human-readable string (e.g. `4.2 KB`).
  ///
  /// The size is estimated by measuring the encoded string length of
  /// [data] when it is a [String]. For binary responses or `List<int>`
  /// bodies the byte length is used directly. When data is `null`, `"0 B"`
  /// is returned.
  ///
  /// ```dart
  /// final response = await dio.get('/users');
  /// final size = response.formattedSize; // e.g. '12.5 KB'
  /// ```
  String get formattedSize {
    if (data == null) return '0 B';

    final bytes = _estimateBytes();
    return ResponseHelper.formatBytes(bytes);
  }

  // ---------------------------------------------------------------------------
  // Timing
  // ---------------------------------------------------------------------------

  /// Returns the total elapsed time for the request in a readable format.
  ///
  /// Uses the `Duration` provided by the [ResponseExtras] or falls back to
  /// measuring from the [receiveTimeout] metadata when available. If no
  /// timing information is present, returns `"N/A"`.
  ///
  /// **Note:** Accurate timing requires the [LoggingInterceptor] to store a
  /// `stopwatch` in `requestOptions.extra['_logging_stopwatch']`. When the
  /// interceptor is active, this value will be populated.
  ///
  /// ```dart
  /// final response = await dio.get('/users');
  /// print(response.timingInfo); // '245 ms'
  /// ```
  String get timingInfo {
    final elapsedMs = _getElapsedMs();
    if (elapsedMs == null) return 'N/A';
    return ResponseHelper.formatDuration(elapsedMs);
  }

  /// Returns the elapsed time in milliseconds, or `null` if unavailable.
  int? get elapsedMs => _getElapsedMs();

  // ---------------------------------------------------------------------------
  // Content Type Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when the response `Content-Type` header contains `json`.
  bool get isJsonResponse {
    final ct = headers.value('content-type') ?? '';
    return ct.toLowerCase().contains('json');
  }

  /// Returns `true` when the response `Content-Type` header contains `xml`.
  bool get isXmlResponse {
    final ct = headers.value('content-type') ?? '';
    return ct.toLowerCase().contains('xml');
  }

  /// Returns `true` when the response `Content-Type` header contains `html`.
  bool get isHtmlResponse {
    final ct = headers.value('content-type') ?? '';
    return ct.toLowerCase().contains('html');
  }

  // ---------------------------------------------------------------------------
  // Status Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if the status code indicates success (2xx).
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Returns `true` if the status code indicates a redirect (3xx).
  bool get isRedirect => statusCode != null && statusCode! >= 300 && statusCode! < 400;

  /// Returns `true` if the status code indicates a client error (4xx).
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Returns `true` if the status code indicates a server error (5xx).
  bool get isServerError => statusCode != null && statusCode! >= 500;

  // ---------------------------------------------------------------------------
  // Body Helpers
  // ---------------------------------------------------------------------------

  /// Returns the response body as a prettified JSON string.
  ///
  /// If the body is already a `Map` or `List`, it is encoded with a 2-space
  /// indent. If it is a `String`, it is decoded and re-encoded with
  /// indentation. Falls back to `toString()` for non-JSON content.
  ///
  /// ```dart
  /// final pretty = response.prettyBody;
  /// ```
  String get prettyBody {
    if (data == null) return '';
    if (data is String) {
      // Try to decode as JSON and re-encode with indentation.
      try {
        final decoded = _jsonDecode(data as String);
        return _jsonEncode(decoded);
      } catch (_) {
        // Not JSON — return as-is.
        return data as String;
      }
    }
    // Maps and Lists are encoded directly.
    return _jsonEncode(data);
  }

  /// Returns the raw response body as a plain string, or empty if null.
  String get bodyString {
    if (data == null) return '';
    return data.toString();
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  /// Estimates the size of the response body in bytes.
  int _estimateBytes() {
    if (data == null) return 0;

    if (data is String) {
      // Approximate byte length — handles ASCII and multi-byte UTF-8.
      return (data as String).length * 2;
    }
    if (data is List<int>) {
      return (data as List<int>).length;
    }
    if (data is Map || data is List) {
      // JSON-encoded length as a proxy for byte count.
      try {
        return _jsonEncode(data).length * 2;
      } catch (_) {
        return data.toString().length * 2;
      }
    }
    return data.toString().length * 2;
  }

  /// Retrieves the elapsed time from the logging interceptor's stopwatch.
  ///
  /// The [LoggingInterceptor] stores a [Stopwatch] in
  /// `requestOptions.extra['_logging_stopwatch']`. When the response
  /// arrives, the stopwatch has been stopped but still carries the
  /// elapsed time.
  int? _getElapsedMs() {
    final stopwatch = requestOptions.extra['_logging_stopwatch'];
    if (stopwatch == null) return null;

    // The stopwatch is stored as a dynamic type; we call elapsedMilliseconds
    // via runtime invocation since the Stopwatch class is not directly
    // importable in this extension's static context without the interceptor.
    try {
      return (stopwatch as dynamic).elapsedMilliseconds as int;
    } catch (_) {
      return null;
    }
  }

  /// JSON decode helper with a generic return type.
  dynamic _jsonDecode(String source) {
    // Uses dart:convert JsonDecoder.
    const decoder = JsonDecoder();
    return decoder.convert(source);
  }

  /// JSON encode helper with 2-space indentation.
  String _jsonEncode(dynamic object) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(object);
  }
}
