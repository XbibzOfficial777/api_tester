/// @file dio_interceptor.dart
/// @brief Custom Dio interceptors for logging, retry, and authentication.
///
/// Three production-grade interceptors that attach to the Dio interceptor
/// pipeline:
///
/// 1. **[LoggingInterceptor]** — logs full request/response details and
///    measures elapsed time for performance profiling.
/// 2. **[RetryInterceptor]** — automatically retries failed requests on
///    transient server errors (5xx) or connection timeouts using an
///    exponential back-off strategy.
/// 3. **[AuthInterceptor]** — injects a `Bearer` token into the
///    `Authorization` header from the currently active environment settings.
///
/// Interceptors are ordered in `injection.dart`; first added runs first on
/// the request path and last on the response path.

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Logging Interceptor
// ---------------------------------------------------------------------------

/// Interceptor that logs request and response details for debugging.
///
/// Captures method, URI, headers, query parameters, request body, response
/// status, response headers, and response body. Time elapsed between sending
/// the request and receiving the response is also measured and logged.
///
/// All output uses [debugPrint] so it automatically appears in the Flutter
/// DevTools console and is stripped in release builds.
///
/// **Note:** This interceptor does **not** log sensitive header values such
/// as `Authorization` or `Cookie` to prevent credential leakage in logs.
class LoggingInterceptor extends Interceptor {
  /// A simple tag prefix used in all log lines for easy filtering.
  static const String _tag = '🛜 API Tester';

  /// Header keys whose values are redacted in log output.
  static const _sensitiveHeaders = {'authorization', 'cookie', 'set-cookie', 'x-api-key'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final stopwatch = Stopwatch()..start();
    // Store the stopwatch in extra so onResponse / onError can read it.
    options.extra[_stopwatchKey] = stopwatch;

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('$_tag ▶ REQUEST  ${options.method} ${options.uri}');

    if (options.headers.isNotEmpty) {
      debugPrint('$_tag   Headers:');
      options.headers.forEach((key, value) {
        final displayValue = _sensitiveHeaders.contains(key.toLowerCase())
            ? '******'
            : value.toString();
        debugPrint('$_tag     $key: $displayValue');
      });
    }

    if (options.queryParameters.isNotEmpty) {
      debugPrint('$_tag   Query Params: ${options.queryParameters}');
    }

    if (options.data != null) {
      final bodyPreview = _truncate(options.data.toString(), 512);
      debugPrint('$_tag   Body: $bodyPreview');
    }

    debugPrint('═══════════════════════════════════════════════════════');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final stopwatch = response.requestOptions.extra[_stopwatchKey] as Stopwatch?;
    stopwatch?.stop();

    final elapsed = stopwatch?.elapsedMilliseconds ?? 0;

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint(
      '$_tag ◀ RESPONSE ${response.statusCode} '
      '${response.requestOptions.method} ${response.requestOptions.uri} '
      '[$elapsed ms]',
    );
    debugPrint('$_tag   Size: ${_formatBytes(response.data.toString().length * 2)}');

    if (response.headers.map.isNotEmpty) {
      debugPrint('$_tag   Response Headers:');
      response.headers.map.forEach((key, value) {
        debugPrint('$_tag     $key: ${value.join(", ")}');
      });
    }

    if (response.data != null) {
      final bodyPreview = _truncate(response.data.toString(), 1024);
      debugPrint('$_tag   Body: $bodyPreview');
    }

    debugPrint('═══════════════════════════════════════════════════════');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final stopwatch = err.requestOptions.extra[_stopwatchKey] as Stopwatch?;
    stopwatch?.stop();

    final elapsed = stopwatch?.elapsedMilliseconds ?? 0;

    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint(
      '$_tag ✕ ERROR    ${err.type} '
      '${err.requestOptions.method} ${err.requestOptions.uri} '
      '[$elapsed ms]',
    );
    debugPrint('$_tag   Message: ${err.message}');
    if (err.response != null) {
      debugPrint('$_tag   Status: ${err.response?.statusCode}');
      debugPrint('$_tag   Body: ${_truncate(err.response?.data.toString() ?? '', 512)}');
    }
    debugPrint('═══════════════════════════════════════════════════════');
    handler.next(err);
  }

  /// Extra-data key used to pass the [Stopwatch] between callbacks.
  static const String _stopwatchKey = '_logging_stopwatch';

  /// Truncates [text] to [maxLen] characters, appending "…" if truncated.
  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}…';
  }

  /// Quick byte-size formatter (does not need the full ResponseHelper).
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Retry Interceptor
// ---------------------------------------------------------------------------

/// Interceptor that retries failed requests up to a configurable count.
///
/// Retries are triggered only for the following error types:
/// - [DioExceptionType.connectionTimeout]
/// - [DioExceptionType.sendTimeout]
/// - [DioExceptionType.receiveTimeout]
/// - [DioExceptionType.connectionError]
/// - Server responses with status 500, 502, 503, or 504
///
/// Back-off is exponential: delay for attempt *n* equals
/// `retryDelays[n]` which defaults to `baseDelay * 2^n`.
class RetryInterceptor extends Interceptor {
  /// Maximum number of retry attempts after the initial request.
  final int retryCount;

  /// List of delays in milliseconds — one per retry attempt.
  ///
  /// If shorter than [retryCount], the last value is reused. If longer,
  /// excess values are ignored.
  final List<int> retryDelays;

  /// HTTP status codes that should trigger a retry.
  static const _retryableStatusCodes = {500, 502, 503, 504};

  /// Creates a [RetryInterceptor].
  ///
  /// [retryCount] defaults to 3. [retryDelays] defaults to exponential
  /// back-off starting at 1000 ms.
  RetryInterceptor({
    this.retryCount = 3,
    List<int>? retryDelays,
  }) : retryDelays = retryDelays ??
            List.generate(
              3,
              (i) => const Duration(seconds: 1).inMilliseconds * (1 << i),
            );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Retrieve current retry attempt from extra data.
    final retryAttempt = err.requestOptions.extra[_retryCountKey] as int? ?? 0;

    final shouldRetry = retryAttempt < retryCount && _isRetryable(err);

    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    // Calculate delay for this attempt.
    final delayIndex = retryAttempt.clamp(0, retryDelays.length - 1);
    final delayMs = retryDelays[delayIndex];

    debugPrint(
      '🔄 RetryInterceptor: '
      'Attempt ${retryAttempt + 1}/$retryCount '
      'after ${delayMs}ms '
      'for ${err.requestOptions.method} ${err.requestOptions.uri}',
    );

    await Future<void>.delayed(Duration(milliseconds: delayMs));

    try {
      // Clone the request with an incremented retry counter.
      final newOptions = RequestOptions(
        method: err.requestOptions.method,
        path: err.requestOptions.path,
        baseUrl: err.requestOptions.baseUrl,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        headers: Map<String, dynamic>.from(err.requestOptions.headers),
        extra: {
          ...err.requestOptions.extra,
          _retryCountKey: retryAttempt + 1,
        },
        contentType: err.requestOptions.contentType,
        responseType: err.requestOptions.responseType,
        validateStatus: err.requestOptions.validateStatus,
        receiveDataWhenStatusError: err.requestOptions.receiveDataWhenStatusError,
        followRedirects: err.requestOptions.followRedirects,
        maxRedirects: err.requestOptions.maxRedirects,
        requestEncoder: err.requestOptions.requestEncoder,
        responseDecoder: err.requestOptions.responseDecoder,
        listFormat: err.requestOptions.listFormat,
      );

      final response = await Dio().fetch(newOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      // Propagate with incremented counter so the next retry (if any) is tracked.
      handler.next(e);
    } catch (e) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        error: e,
        type: DioExceptionType.unknown,
      ));
    }
  }

  /// Determines whether the given [DioException] is eligible for retry.
  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return _retryableStatusCodes.contains(err.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  /// Extra-data key for tracking retry attempts across interceptor calls.
  static const String _retryCountKey = '_retry_attempt';
}

// ---------------------------------------------------------------------------
// Auth Interceptor
// ---------------------------------------------------------------------------

/// Interceptor that injects a Bearer token from environment settings.
///
/// The interceptor checks the request's [RequestOptions.extra] map for a
/// key `'auth_token'`. If present and non-empty, it prepends `Bearer ` and
/// sets the `Authorization` header. If the header already exists it will be
/// overwritten to ensure the latest token is always used.
///
/// This design decouples the interceptor from any specific state-management
/// library — the calling code simply passes the token via `extra`.
///
/// ```dart
/// try {
///   final response = await dio.fetch(
///     RequestOptions(
///       path: '/users',
///       extra: {'auth_token': currentToken},
///     ),
///   );
/// } catch (_) { ... }
/// ```
class AuthInterceptor extends Interceptor {
  /// The key used in [RequestOptions.extra] to look up the Bearer token.
  static const String authTokenKey = 'auth_token';

  /// The HTTP header name for the Authorization field.
  static const String _authorizationHeader = 'Authorization';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = options.extra[authTokenKey] as String?;

    if (token != null && token.isNotEmpty) {
      options.headers[_authorizationHeader] = 'Bearer $token';
      // Remove from extra to avoid leaking into request body/logs.
      options.extra.remove(authTokenKey);
    }

    handler.next(options);
  }
}

// ---------------------------------------------------------------------------
// Utility: Jitter Helper
// ---------------------------------------------------------------------------

/// Adds random jitter (±25 %) to a base delay to avoid thundering-herd.
///
/// Used internally by [RetryInterceptor] when callers need jitter applied
/// to their delay values. Exposed as a top-level helper for reuse in tests.
int addJitter(int baseDelayMs) {
  final rng = Random();
  final jitterFactor = 0.25;
  final jitter = (baseDelayMs * jitterFactor).toInt();
  return (baseDelayMs + (rng.nextInt(jitter * 2) - jitter))
      .clamp(0, baseDelayMs * 2);
}
