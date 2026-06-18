/// @file runner_result.dart
/// @brief Domain entity for the overall result of a collection runner execution.
///
/// Aggregates the results of all requests executed in a collection run,
/// providing summary statistics and the status of the entire operation.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'request_runner_result.dart';

part 'runner_result.freezed.dart';
part 'runner_result.g.dart';

/// The overall status of a collection runner execution.
enum RunnerStatus {
  /// The collection run is currently in progress.
  @JsonValue('running')
  running,

  /// All requests in the collection have been executed.
  @JsonValue('completed')
  completed,

  /// The collection run encountered a critical error.
  @JsonValue('failed')
  failed,

  /// The collection run was cancelled by the user.
  @JsonValue('cancelled')
  cancelled,
}

/// The complete result of executing a collection of requests.
///
/// Contains aggregate statistics (total, passed, failed) and the
/// individual results for each request in the execution order.
/// This entity is persisted for historical reference and comparison.
@freezed
class RunnerResult with _$RunnerResult {
  /// Creates a new [RunnerResult] instance.
  ///
  /// [id] - Unique identifier for this runner execution.
  /// [collectionId] - The collection that was executed.
  /// [totalRequests] - Total number of requests that were part of the collection.
  /// [passedCount] - Number of requests where all assertions passed.
  /// [failedCount] - Number of requests that failed or had failing assertions.
  /// [results] - Detailed results for each executed request, in order.
  /// [startedAt] - Timestamp when the collection run started.
  /// [completedAt] - Timestamp when the collection run finished.
  /// [durationMs] - Total duration of the collection run in milliseconds.
  /// [status] - The final status of the collection run.
  const factory RunnerResult({
    required String id,
    required String collectionId,
    @Default(0) int totalRequests,
    @Default(0) int passedCount,
    @Default(0) int failedCount,
    @Default([]) List<RequestRunnerResult> results,
    required DateTime startedAt,
    DateTime? completedAt,
    @Default(0) int durationMs,
    @Default(RunnerStatus.running) RunnerStatus status,
  }) = _RunnerResult;

  /// Deserializes a [RunnerResult] from a JSON map.
  factory RunnerResult.fromJson(Map<String, dynamic> json) =>
      _$RunnerResultFromJson(json);
}