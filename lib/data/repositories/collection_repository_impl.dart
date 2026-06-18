/// Implementation of [CollectionRepository] backed by the Drift local
/// database.
library;

import 'package:drift/drift.dart';

import '../../../domain/entities/collection.dart';
import '../../../domain/repositories/collection_repository.dart';
import '../datasources/local/database/app_database.dart';
import '../datasources/local/database/tables.dart';
import '../mappers/collection_mapper.dart';

/// Concrete [CollectionRepository] that persists collections to SQLite.
class CollectionRepositoryImpl implements CollectionRepository {
  /// The Drift database instance, typically injected via a DI container.
  final AppDatabase _db;

  /// Creates a [CollectionRepositoryImpl] backed by [_db].
  CollectionRepositoryImpl(this._db);

  // ---------------------------------------------------------------------------
  // CollectionRepository
  // ---------------------------------------------------------------------------

  @override
  Future<List<Collection>> getCollectionsByWorkspace(
      String workspaceId) async {
    try {
      final rows =
          await _db.collectionDao.getCollectionsByWorkspace(workspaceId);
      return CollectionMapper.toEntityList(rows);
    } catch (e) {
      throw Exception(
          'Failed to fetch collections for workspace "$workspaceId": $e');
    }
  }

  @override
  Future<Collection> getCollection(String id) async {
    try {
      final row = await _db.collectionDao.getCollectionById(id);
      if (row == null) {
        throw Exception('Collection with id "$id" not found.');
      }
      return CollectionMapper.toEntity(row);
    } catch (e) {
      throw Exception('Failed to fetch collection with id "$id": $e');
    }
  }

  Future<Collection?> getCollectionById(String id) async {
    try {
      final row = await _db.collectionDao.getCollectionById(id);
      return row != null ? CollectionMapper.toEntity(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch collection with id "$id": $e');
    }
  }

  @override
  Future<Collection> createCollection(Collection collection) async {
    try {
      final companion = CollectionMapper.fromEntity(collection);
      await _db.collectionDao.insertCollection(companion);
      return collection;
    } catch (e) {
      throw Exception(
          'Failed to create collection "${collection.name}": $e');
    }
  }

  @override
  Future<Collection> updateCollection(Collection collection) async {
    try {
      final companion = CollectionMapper.fromEntity(collection);
      final updated = await _db.collectionDao.updateCollection(companion);
      if (!updated) {
        throw Exception('Collection with id "${collection.id}" not found.');
      }
      return collection;
    } catch (e) {
      throw Exception(
          'Failed to update collection "${collection.name}": $e');
    }
  }

  @override
  Future<void> deleteCollection(String id) async {
    try {
      // Clear the collection reference from any request that belongs to
      // this collection so that they become standalone.
      final requests = await _db.requestDao.getRequestsByCollection(id);
      for (final req in requests) {
        await _db.requestDao.updateRequest(
          ApiRequestsCompanion(
            id: Value(req.id),
            collectionId: const Value(null),
          ),
        );
      }
      await _db.collectionDao.deleteCollection(id);
    } catch (e) {
      throw Exception('Failed to delete collection with id "$id": $e');
    }
  }

  @override
  Future<void> addRequestToCollection(
    String collectionId,
    String requestId, {
    int? index,
  }) async {
    try {
      final collection = await getCollection(collectionId);
      if (collection.requestIds.contains(requestId)) return;

      final newIds = List<String>.from(collection.requestIds);
      if (index != null && index >= 0 && index <= newIds.length) {
        newIds.insert(index, requestId);
      } else {
        newIds.add(requestId);
      }

      final updated = collection.copyWith(
        requestIds: newIds,
        updatedAt: DateTime.now(),
      );
      await _db.collectionDao.updateCollection(
        CollectionMapper.fromEntity(updated),
      );
    } catch (e) {
      throw Exception(
          'Failed to add request "$requestId" to collection "$collectionId": $e');
    }
  }

  @override
  Future<void> removeRequestFromCollection(
    String collectionId,
    String requestId,
  ) async {
    try {
      final collection = await getCollection(collectionId);
      if (!collection.requestIds.contains(requestId)) return;

      final newIds = List<String>.from(collection.requestIds)
        ..remove(requestId);

      final updated = collection.copyWith(
        requestIds: newIds,
        updatedAt: DateTime.now(),
      );
      await _db.collectionDao.updateCollection(
        CollectionMapper.fromEntity(updated),
      );
    } catch (e) {
      throw Exception(
          'Failed to remove request "$requestId" from collection "$collectionId": $e');
    }
  }

  @override
  Future<void> reorderRequests(
    String collectionId,
    List<String> requestIds,
  ) async {
    try {
      final collection = await getCollection(collectionId);

      // Validate that the new list contains the same IDs as the current one.
      final currentSet = collection.requestIds.toSet();
      final newSet = requestIds.toSet();
      if (currentSet != newSet) {
        throw ArgumentError(
          'reorderRequests: the provided requestIds do not match the '
          'current collection contents.',
        );
      }

      final updated = collection.copyWith(
        requestIds: requestIds,
        updatedAt: DateTime.now(),
      );
      await _db.collectionDao.updateCollection(
        CollectionMapper.fromEntity(updated),
      );
    } catch (e) {
      throw Exception(
          'Failed to reorder requests in collection "$collectionId": $e');
    }
  }

  Future<void> deleteCollectionsByWorkspace(String workspaceId) async {
    try {
      await _db.collectionDao.deleteCollectionsByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to delete collections for workspace "$workspaceId": $e');
    }
  }

  Stream<List<Collection>> watchCollectionsByWorkspace(String workspaceId) {
    try {
      return _db.collectionDao
          .watchCollectionsByWorkspace(workspaceId)
          .map(CollectionMapper.toEntityList);
    } catch (e) {
      throw Exception(
          'Failed to watch collections for workspace "$workspaceId": $e');
    }
  }
}