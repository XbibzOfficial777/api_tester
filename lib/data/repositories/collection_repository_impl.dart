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
  Future<void> deleteCollectionsByWorkspace(String workspaceId) async {
    try {
      await _db.collectionDao.deleteCollectionsByWorkspace(workspaceId);
    } catch (e) {
      throw Exception(
          'Failed to delete collections for workspace "$workspaceId": $e');
    }
  }

  @override
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