/// Data Access Object for the [Environments] table.
///
/// Provides typed CRUD helpers, active-environment management, and reactive
/// watch queries.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'environment_dao.g.dart';

/// DAO encapsulating all database operations on the **environments** table.
@DriftAccessor(tables: [Environments])
class EnvironmentDao extends DatabaseAccessor<AppDatabase>
    with _$EnvironmentDaoMixin {
  /// Creates an [EnvironmentDao] bound to the given [db] instance.
  EnvironmentDao(super.db);

  /// Returns all environments belonging to [workspaceId], ordered by name.
  Future<List<EnvironmentTableData>> getEnvironmentsByWorkspace(
      String workspaceId) {
    return (select(environments)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a single environment by its primary key, or `null`.
  Future<EnvironmentTableData?> getEnvironmentById(String id) {
    return (select(environments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns the currently active environment for [workspaceId], or `null`
  /// when no environment is active.
  Future<EnvironmentTableData?> getActiveEnvironment(String workspaceId) {
    return (select(environments)
          ..where(
            (t) => t.workspaceId.equals(workspaceId) & t.isActive.equals(true),
          ))
        .getSingleOrNull();
  }

  /// Returns the global environment for [workspaceId], or `null`.
  Future<EnvironmentTableData?> getGlobalEnvironment(String workspaceId) {
    return (select(environments)
          ..where(
            (t) => t.workspaceId.equals(workspaceId) & t.isGlobal.equals(true),
          ))
        .getSingleOrNull();
  }

  /// Returns a reactive stream of environments for [workspaceId].
  Stream<List<EnvironmentTableData>> watchEnvironmentsByWorkspace(
      String workspaceId) {
    return (select(environments)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Inserts a new environment row (upsert semantics).
  Future<void> insertEnvironment(EnvironmentsCompanion entry) {
    return into(environments)
        .insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Updates an existing environment row identified by its primary key.
  Future<bool> updateEnvironment(EnvironmentsCompanion entry) {
    return (update(environments)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Deactivates **all** environments in the given [workspaceId], then
  /// activates only the one with the given [environmentId].
  ///
  /// This operation is performed inside an explicit transaction so that
  /// there is never a state where zero or multiple environments are active.
  Future<void> setActiveEnvironment(
      String workspaceId, String environmentId) async {
    await transaction(() async {
      // Deactivate everything in the workspace.
      await (update(environments)
            ..where((t) => t.workspaceId.equals(workspaceId)))
          .write(const EnvironmentsCompanion(isActive: Value(false)));

      // Activate the target environment.
      await (update(environments)..where((t) => t.id.equals(environmentId)))
          .write(const EnvironmentsCompanion(isActive: Value(true)));
    });
  }

  /// Deletes the environment identified by [id].
  Future<void> deleteEnvironment(String id) {
    return (delete(environments)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes **all** environments whose workspace matches [workspaceId].
  Future<void> deleteEnvironmentsByWorkspace(String workspaceId) {
    return (delete(environments)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .go();
  }
}