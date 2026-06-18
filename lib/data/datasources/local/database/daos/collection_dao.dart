/// Data Access Object for the [Collections] table.
///
/// Provides typed CRUD helpers, filtering by workspace, and reactive watch
/// queries.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'collection_dao.g.dart';

/// DAO encapsulating all database operations on the **collections** table.
@DriftAccessor(tables: [Collections])
class CollectionDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionDaoMixin {
  /// Creates a [CollectionDao] bound to the given [db] instance.
  CollectionDao(super.db);

  /// Returns all collections belonging to [workspaceId], ordered by name.
  Future<List<CollectionTableData>> getCollectionsByWorkspace(
      String workspaceId) {
    return (select(collections)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a single collection by its primary key, or `null`.
  Future<CollectionTableData?> getCollectionById(String id) {
    return (select(collections)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns a reactive stream of collections for [workspaceId].
  Stream<List<CollectionTableData>> watchCollectionsByWorkspace(
      String workspaceId) {
    return (select(collections)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Inserts a new collection row (upsert semantics).
  Future<void> insertCollection(CollectionsCompanion entry) {
    return into(collections).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Updates an existing collection row identified by its primary key.
  Future<bool> updateCollection(CollectionsCompanion entry) {
    return (update(collections)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Deletes the collection identified by [id].
  Future<void> deleteCollection(String id) {
    return (delete(collections)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes **all** collections whose workspace matches [workspaceId].
  Future<void> deleteCollectionsByWorkspace(String workspaceId) {
    return (delete(collections)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .go();
  }
}