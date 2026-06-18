/// Data Access Object for the [RequestHistory] table.
///
/// Provides typed CRUD helpers, pinning support, and reactive watch queries.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'history_dao.g.dart';

/// DAO encapsulating all database operations on the **request_history** table.
@DriftAccessor(tables: [RequestHistory])
class HistoryDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryDaoMixin {
  /// Creates a [HistoryDao] bound to the given [db] instance.
  HistoryDao(super.db);

  /// Returns all history entries for [workspaceId], pinned entries first,
  /// then by most recent timestamp.
  Future<List<RequestHistoryTableData>> getHistoryByWorkspace(
      String workspaceId) {
    return (select(requestHistory)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.timestamp),
          ]))
        .get();
  }

  /// Returns a single history entry by its primary key, or `null`.
  Future<RequestHistoryTableData?> getHistoryById(String id) {
    return (select(requestHistory)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns all history entries related to [requestId], most recent first.
  Future<List<RequestHistoryTableData>> getHistoryByRequest(
      String requestId) {
    return (select(requestHistory)
          ..where((t) => t.requestId.equals(requestId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  /// Returns a reactive stream of history entries for [workspaceId].
  Stream<List<RequestHistoryTableData>> watchHistoryByWorkspace(
      String workspaceId) {
    return (select(requestHistory)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.timestamp),
          ]))
        .watch();
  }

  /// Inserts a new history entry (upsert semantics).
  Future<void> insertHistoryEntry(RequestHistoryCompanion entry) {
    return into(requestHistory)
        .insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Toggles the [RequestHistory.isPinned] flag for the given [id].
  ///
  /// Reads the current state first, then writes the inverse value.
  Future<void> togglePin(String id) async {
    final entry = await getHistoryById(id);
    if (entry == null) return;

    final newPinnedValue = !entry.isPinned;
    await (update(requestHistory)..where((t) => t.id.equals(id)))
        .write(RequestHistoryCompanion(
      isPinned: Value(newPinnedValue),
    ));
  }

  /// Deletes the history entry identified by [id].
  Future<void> deleteHistoryEntry(String id) {
    return (delete(requestHistory)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes **all** history entries whose workspace matches [workspaceId].
  Future<void> deleteHistoryByWorkspace(String workspaceId) {
    return (delete(requestHistory)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .go();
  }

  /// Deletes all history entries related to a specific [requestId].
  Future<void> deleteHistoryByRequest(String requestId) {
    return (delete(requestHistory)
          ..where((t) => t.requestId.equals(requestId)))
        .go();
  }
}