/// @file history_provider.dart
/// @brief Riverpod providers for request history.
///
/// Provides the history list for the current workspace, sorted by
/// timestamp descending with pinned entries first. Supports search,
/// pin/unpin, and bulk clear operations.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/request_history.dart';
import 'package:api_tester/domain/repositories/history_repository.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the async state of the request history list.
///
/// History entries are fetched sorted by timestamp descending, with
/// pinned entries always appearing at the top.
class HistoryListNotifier extends AsyncNotifier<List<RequestHistory>> {
  HistoryRepository get _repo => getIt<HistoryRepository>();

  @override
  Future<List<RequestHistory>> build() async {
    // Watch the current workspace so we reload on workspace change.
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace == null) return [];
    return _repo.getHistory(workspace.id);
  }

  /// Reloads history from the repository (e.g. after sending a request).
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchHistory);
  }

  /// Internal helper that fetches history for the current workspace.
  Future<List<RequestHistory>> _fetchHistory() async {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return [];
    return _repo.getHistory(workspace.id);
  }

  /// Deletes a single history entry by [id].
  ///
  /// Removes the entry from the local state and the repository.
  Future<void> deleteHistoryItem(String id) async {
    final previousState = state;

    // Optimistic removal.
    state.whenData((list) {
      state = AsyncValue.data(
        list.where((h) => h.id != id).toList(),
      );
    });

    try {
      await _repo.deleteHistoryItem(id);
    } catch (e, st) {
      state = previousState;
      state = AsyncValue.error(e, st);
    }
  }

  /// Clears all history entries for the current workspace.
  ///
  /// This is irreversible – including pinned entries.
  Future<void> clearHistory() async {
    try {
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace == null) return;

      await _repo.clearHistory(workspace.id);
      state = const AsyncValue.data([]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Pins a history entry so it appears at the top of the list.
  ///
  /// After pinning, the list is re-sorted (pinned first, then by
  /// timestamp descending).
  Future<void> pinItem(String id) async {
    try {
      await _repo.pinHistoryItem(id);

      // Update the local entry and re-sort.
      state.whenData((list) {
        final updated = list.map((h) {
          return h.id == id ? h.copyWith(isPinned: true) : h;
        }).toList();
        // Re-sort: pinned first, then by timestamp descending.
        updated.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.timestamp.compareTo(a.timestamp);
        });
        state = AsyncValue.data(updated);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Unpins a previously pinned history entry.
  Future<void> unpinItem(String id) async {
    try {
      await _repo.unpinHistoryItem(id);

      state.whenData((list) {
        final updated = list.map((h) {
          return h.id == id ? h.copyWith(isPinned: false) : h;
        }).toList();
        // Re-sort: pinned first, then by timestamp descending.
        updated.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.timestamp.compareTo(a.timestamp);
        });
        state = AsyncValue.data(updated);
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Searches history entries by [query] text.
  ///
  /// Performs a case-insensitive search across request names, URLs, and
  /// HTTP methods. The results replace the current state (not appended).
  /// Pass an empty query to restore the full history list.
  Future<void> searchHistory(String query) async {
    if (query.trim().isEmpty) {
      // Restore the full list.
      await reload();
      return;
    }

    try {
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final results = await _repo.searchHistory(query, workspace.id);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the request history for the current workspace.
///
/// Entries are sorted by timestamp descending with pinned entries first.
/// Rebuilds automatically when the workspace changes.
final historyListProvider =
    AsyncNotifierProvider<HistoryListNotifier, List<RequestHistory>>(
  HistoryListNotifier.new,
);