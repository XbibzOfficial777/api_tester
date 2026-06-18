/// @file history_repository.dart
/// @brief Repository interface for [RequestHistory] entity management.
///
/// Provides methods for querying, searching, and managing the request
/// execution history, including pin/unpin functionality.
library;

import '../entities/request_history.dart';

/// Abstract repository providing CRUD and search operations for
/// [RequestHistory] entities.
abstract class HistoryRepository {
  /// Retrieves the request history for a workspace.
  ///
  /// [workspaceId] - The UUID of the workspace to filter by.
  /// [limit] - Maximum number of entries to return. Defaults to 50.
  /// [offset] - Number of entries to skip (for pagination). Defaults to 0.
  ///
  /// Returns history entries sorted by timestamp descending (most recent first),
  /// with pinned entries appearing at the top regardless of timestamp.
  Future<List<RequestHistory>> getHistory(
    String workspaceId, {
    int limit = 50,
    int offset = 0,
  });

  /// Adds a new entry to the request history.
  ///
  /// [history] - The history entry to persist.
  ///
  /// If the history list exceeds a configurable maximum (e.g., 1000 entries),
  /// the oldest non-pinned entries should be pruned automatically.
  Future<void> addToHistory(RequestHistory history);

  /// Deletes a single history entry.
  ///
  /// [id] - The UUID of the history entry to delete.
  Future<void> deleteHistoryItem(String id);

  /// Clears all history entries for a workspace.
  ///
  /// [workspaceId] - The UUID of the workspace.
  ///
  /// Removes all entries including pinned ones.
  Future<void> clearHistory(String workspaceId);

  /// Pins a history entry so it always appears at the top of the list.
  ///
  /// [id] - The UUID of the history entry to pin.
  Future<void> pinHistoryItem(String id);

  /// Unpins a previously pinned history entry.
  ///
  /// [id] - The UUID of the history entry to unpin.
  Future<void> unpinHistoryItem(String id);

  /// Searches history entries by query text.
  ///
  /// [query] - The search string to match against name, URL, and method.
  /// [workspaceId] - The UUID of the workspace to search within.
  ///
  /// Performs a case-insensitive search across request names, URLs,
  /// and HTTP methods. Returns matching entries sorted by relevance
  /// (exact matches first, then partial matches).
  Future<List<RequestHistory>> searchHistory(
    String query,
    String workspaceId,
  );
}