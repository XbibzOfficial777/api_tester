/// Data Access Object for the [Workspaces] table.
///
/// Provides typed CRUD helpers and reactive watch queries so that the
/// repository layer never has to write raw SQL.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'workspace_dao.g.dart';

/// DAO encapsulating all database operations on the **workspaces** table.
@DriftAccessor(tables: [Workspaces])
class WorkspaceDao extends DatabaseAccessor<AppDatabase>
    with _$WorkspaceDaoMixin {
  /// Creates a [WorkspaceDao] bound to the given [db] instance.
  WorkspaceDao(super.db);

  /// Returns **all** workspaces, ordered by most recently updated first.
  Future<List<WorkspaceTableData>> getAllWorkspaces() {
    return (select(workspaces)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  /// Returns a single workspace by its primary key, or `null`.
  Future<WorkspaceTableData?> getWorkspaceById(String id) {
    return (select(workspaces)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Returns a [Stream] that re-emits the full workspace list whenever the
  /// table is modified.
  Stream<List<WorkspaceTableData>> watchAllWorkspaces() {
    return (select(workspaces)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  /// Inserts a new workspace row.
  ///
  /// Uses `mode: InsertMode.insertOrReplace` so that calling code can
  /// safely re-insert without worrying about duplicate-key conflicts.
  Future<void> insertWorkspace(WorkspacesCompanion entry) {
    return into(workspaces).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Updates an existing workspace row identified by its primary key.
  Future<bool> updateWorkspace(WorkspacesCompanion entry) {
    return (update(workspaces)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Deletes the workspace identified by [id].
  ///
  /// **Note:** Cascading deletion of related rows (requests, collections,
  /// environments, history) is NOT handled here – the repository or
  /// database migration should take care of that.
  Future<void> deleteWorkspace(String id) {
    return (delete(workspaces)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes **all** rows from the workspaces table.
  Future<void> deleteAllWorkspaces() {
    return delete(workspaces).go();
  }
}