/// Remote API service that wraps [Dio] for all outbound HTTP traffic.
///
/// This class provides a thin, method-specific façade over Dio so that
/// callers do not need to import Dio directly. Each method handles errors
/// consistently and returns the raw [Response] for the repository layer
/// to deconstruct.
library;

import 'package:dio/dio.dart';

/// Centralised HTTP client for the API Tester application.
///
/// ### Usage
/// ```dart
/// final api = ApiService(dio);
/// final response = await api.get(
///   'https://jsonplaceholder.typicode.com/posts/1',
///   headers: {'Accept': 'application/json'},
/// );
/// ```
class ApiService {
  /// The underlying [Dio] instance used to perform HTTP requests.
  final Dio _dio;

  /// Creates an [ApiService] wrapping the given [Dio] instance.
  ///
  /// Injecting Dio (rather than constructing it internally) makes the
  /// service easy to test with interceptors or mock adapters.
  ApiService(this._dio);

  // ---------------------------------------------------------------------------
  // Convenience HTTP methods
  // ---------------------------------------------------------------------------

  /// Sends an HTTP GET request to [url].
  ///
  /// [queryParameters] and [headers] are optional maps that are merged
  /// into the request.
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        url,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP POST request to [url] with an optional [body].
  Future<Response> post(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        url,
        data: body,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP PUT request to [url] with an optional [body].
  Future<Response> put(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        url,
        data: body,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP PATCH request to [url] with an optional [body].
  Future<Response> patch(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        url,
        data: body,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP DELETE request to [url] with an optional [body].
  Future<Response> delete(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        url,
        data: body,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP HEAD request to [url].
  Future<Response> head(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      return await _dio.head(
        url,
        queryParameters: queryParameters,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Sends an HTTP OPTIONS request to [url].
  Future<Response> options(
    String url, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      final merged = _mergeOptions(options, headers)..method = 'OPTIONS';
      return await _dio.request(
        url,
        data: body,
        queryParameters: queryParameters,
        options: merged,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Merges caller-supplied [extraHeaders] into the given [baseOptions].
  ///
  /// When [baseOptions] is `null` a fresh [Options] is created.
  /// Headers from [extraHeaders] take precedence when there is a collision.
  static Options _mergeOptions(Options? baseOptions, Map<String, dynamic>? extraHeaders) {
    final merged = baseOptions ?? Options();
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      merged.headers = {
        ...?merged.headers,
        ...extraHeaders,
      };
    }
    return merged;
  }

  /// Converts a [DioException] into a plain [Exception] with a human-readable
  /// message that the UI layer can display without depending on Dio.
  static Exception _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('Connection timeout: the server did not respond within the configured time limit.');
      case DioExceptionType.sendTimeout:
        return Exception('Send timeout: the request could not be sent within the configured time limit.');
      case DioExceptionType.receiveTimeout:
        return Exception('Receive timeout: the server stopped sending data within the configured time limit.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final statusMessage = e.response?.statusMessage ?? 'Unknown';
        return Exception('Server returned $statusCode $statusMessage.');
      case DioExceptionType.cancel:
        return Exception('Request was cancelled.');
      case DioExceptionType.connectionError:
        return Exception('Connection error: unable to reach the server. Please check your network connection.');
      case DioExceptionType.badCertificate:
        return Exception('SSL certificate verification failed.');
      case DioExceptionType.unknown:
        return Exception('An unexpected error occurred: ${e.message ?? e.error}');
    }
  }
}