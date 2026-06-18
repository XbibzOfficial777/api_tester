/// @file request_history.dart
/// @brief Domain entity for a request history entry.
///
/// Provides a lightweight, searchable record of previously sent requests.
/// Unlike the full [ApiResponse] entity, history entries capture only the
/// essential information needed for quick reference and re-execution.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'api_request.dart';

part 'request_history.freezed.dart';
part 'request_history.g.dart';

/// A lightweight record of a previously sent API request.
///
/// History entries are displayed in the history panel, allowing users
/// to quickly review, search, and re-execute past requests. Entries
/// can be pinned to keep them at the top of the list.
@freezed
class RequestHistory with _$RequestHistory {
  /// Creates a new [RequestHistory] instance.
  ///
  /// [id] - Unique identifier for this history entry.
  /// [workspaceId] - The workspace context where the request was sent.
  /// [requestId] - The ID of the original [ApiRequest] that was sent.
  /// [name] - The name of the request at the time it was sent.
  /// [method] - The HTTP method used.
  /// [url] - The fully resolved URL (with variables substituted) that was called.
  /// [statusCode] - The HTTP status code received in the response.
  /// [responseTimeMs] - How long the request took in milliseconds.
  /// [timestamp] - When this request was sent.
  /// [isPinned] - Whether this entry is pinned to the top of the history list.
  const factory RequestHistory({
    required String id,
    required String workspaceId,
    required String requestId,
    required String name,
    required HttpMethod method,
    required String url,
    int? statusCode,
    @Default(0) int responseTimeMs,
    required DateTime timestamp,
    @Default(false) bool isPinned,
  }) = _RequestHistory;

  /// Deserializes a [RequestHistory] from a JSON map.
  factory RequestHistory.fromJson(Map<String, dynamic> json) =>
      _$RequestHistoryFromJson(json);
}