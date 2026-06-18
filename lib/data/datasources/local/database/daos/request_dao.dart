/// Data Access Object for the [ApiRequests] table.
///
/// Provides typed CRUD helpers, filtering by workspace / collection, and
/// reactive watch queries.
library;

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'request_dao.g.dart';

/// DAO encapsulating all database operations on the **api_requests** table.
@DriftAccessor(tables: [ApiRequests])
class RequestDao extends DatabaseAccessor<AppDatabase>
    with _$RequestDaoMixin {
  /// Creates a [RequestDao] bound to the given [db] instance.
  RequestDao(super.db);

  /// Returns every request belonging to [workspaceId], ordered by most
  /// recently updated first.
  Future<List<ApiRequestTableData>> getRequestsByWorkspace(String workspaceId) {
    return (select(apiRequests)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Returns a single request by its primary key, or `null`.
  Future<ApiRequestTableData?> getRequestById(String id) {
    return (select(apiRequests)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns all requests whose [ApiRequests.collectionId] matches the given
  /// [collectionId].
  Future<List<ApiRequestTableData>> getRequestsByCollection(
      String collectionId) {
    return (select(apiRequests)
          ..where((t) => t.collectionId.equals(collectionId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a reactive stream of requests for [workspaceId].
  Stream<List<ApiRequestTableData>> watchRequestsByWorkspace(
      String workspaceId) {
    return (select(apiRequests)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Returns a reactive stream of requests for a given [collectionId].
  Stream<List<ApiRequestTableData>> watchRequestsByCollection(
      String collectionId) {
    return (select(apiRequests)
          ..where((t) => t.collectionId.equals(collectionId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Inserts a new request row (upsert semantics).
  Future<void> insertRequest(ApiRequestsCompanion entry) {
    return into(apiRequests).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Updates an existing request row identified by its primary key.
  Future<bool> updateRequest(ApiRequestsCompanion entry) {
    return (update(apiRequests)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Deletes the request identified by [id].
  Future<void> deleteRequest(String id) {
    return (delete(apiRequests)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes **all** requests whose workspace matches [workspaceId].
  Future<void> deleteRequestsByWorkspace(String workspaceId) {
    return (delete(apiRequests)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .go();
  }

  /// Deletes **all** requests whose collection matches [collectionId].
  Future<void> deleteRequestsByCollection(String collectionId) {
    return (delete(apiRequests)
          ..where((t) => t.collectionId.equals(collectionId)))
        .go();
  }
}