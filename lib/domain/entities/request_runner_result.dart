/// @file request_runner_result.dart
/// @brief Domain entity for the result of a single request in a collection run.
///
/// Captures the outcome of executing one request within a collection
/// runner session, including the response summary, assertion results,
/// and any error that occurred during execution.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'assertion.dart';

part 'request_runner_result.freezed.dart';
part 'request_runner_result.g.dart';

/// The execution result of a single request in a collection run.
///
/// Provides a compact summary suitable for displaying in a results
/// table, including whether all assertions passed and the truncated
/// response body for quick inspection.
@freezed
class RequestRunnerResult with _$RequestRunnerResult {
  /// Creates a new [RequestRunnerResult] instance.
  ///
  /// [requestId] - The ID of the request that was executed.
  /// [requestName] - The display name of the request.
  /// [method] - The HTTP method used.
  /// [url] - The URL that was called.
  /// [statusCode] - The HTTP status code received (null if request failed).
  /// [responseTimeMs] - How long the request took in milliseconds.
  /// [responseBody] - The response body, truncated for display purposes.
  /// [assertions] - List of assertion results for this request.
  /// [allAssertionsPassed] - Whether every assertion passed (or no assertions defined).
  /// [error] - Error message if the request could not be completed.
  /// [timestamp] - When this request was executed.
  const factory RequestRunnerResult({
    required String requestId,
    required String requestName,
    required String method,
    required String url,
    int? statusCode,
    @Default(0) int responseTimeMs,
    @Default('') String responseBody,
    @Default([]) List<Assertion> assertions,
    @Default(true) bool allAssertionsPassed,
    String? error,
    required DateTime timestamp,
  }) = _RequestRunnerResult;

  /// Deserializes a [RequestRunnerResult] from a JSON map.
  factory RequestRunnerResult.fromJson(Map<String, dynamic> json) =>
      _$RequestRunnerResultFromJson(json);
}