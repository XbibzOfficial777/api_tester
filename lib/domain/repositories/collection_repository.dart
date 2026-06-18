/// @file collection_repository.dart
/// @brief Repository interface for [Collection] entity CRUD and management.
///
/// Provides CRUD operations for collections as well as methods for
/// managing the requests within a collection (adding, removing, reordering).
library;

import '../entities/collection.dart';

/// Abstract repository providing CRUD and request management operations
/// for [Collection] entities.
abstract class CollectionRepository {
  /// Retrieves a single collection by its unique identifier.
  ///
  /// [id] - The UUID of the collection to retrieve.
  Future<Collection> getCollection(String id);

  /// Retrieves all collections belonging to a specific workspace.
  ///
  /// [workspaceId] - The UUID of the workspace to filter by.
  ///
  /// Returns collections sorted alphabetically by name.
  Future<List<Collection>> getCollectionsByWorkspace(String workspaceId);

  /// Creates a new collection and persists it to storage.
  ///
  /// [collection] - The collection entity to create.
  ///
  /// Returns the persisted collection with any server-generated fields.
  Future<Collection> createCollection(Collection collection);

  /// Updates an existing collection with new values.
  ///
  /// [collection] - The collection entity with updated fields.
  Future<Collection> updateCollection(Collection collection);

  /// Permanently deletes a collection by its unique identifier.
  ///
  /// [id] - The UUID of the collection to delete.
  ///
  /// Does not delete the individual requests; they become unassociated.
  Future<void> deleteCollection(String id);

  /// Adds a request to a collection at the specified position.
  ///
  /// [collectionId] - The UUID of the target collection.
  /// [requestId] - The UUID of the request to add.
  /// [index] - Optional zero-based position to insert at. If null or
  /// greater than the current size, the request is appended to the end.
  ///
  /// If the request is already in the collection, this is a no-op.
  Future<void> addRequestToCollection(
    String collectionId,
    String requestId, {
    int? index,
  });

  /// Removes a request from a collection.
  ///
  /// [collectionId] - The UUID of the collection.
  /// [requestId] - The UUID of the request to remove.
  ///
  /// If the request is not in the collection, this is a no-op.
  Future<void> removeRequestFromCollection(
    String collectionId,
    String requestId,
  );

  /// Reorders the requests within a collection.
  ///
  /// [collectionId] - The UUID of the collection to reorder.
  /// [requestIds] - The new ordered list of request IDs. Must contain
  /// exactly the same IDs as the current collection (order may differ).
  ///
  /// Throws [ArgumentError] if [requestIds] does not match the current
  /// collection's request set.
  Future<void> reorderRequests(
    String collectionId,
    List<String> requestIds,
  );
}