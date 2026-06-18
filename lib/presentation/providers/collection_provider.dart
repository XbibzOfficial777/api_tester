/// @file collection_provider.dart
/// @brief Riverpod providers for collection management.
///
/// Provides the collection list (filtered by the current workspace),
/// the currently selected collection, and CRUD / request-management
/// methods that delegate to [CollectionRepository].

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/domain/repositories/collection_repository.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the async state of the collection list for the current workspace.
///
/// Automatically reloads when the current workspace changes. Exposes
/// mutation methods that keep the UI in sync.
class CollectionListNotifier extends AsyncNotifier<List<Collection>> {
  CollectionRepository get _repo => getIt<CollectionRepository>();

  @override
  Future<List<Collection>> build() async {
    // Watch the current workspace so we reload when it changes.
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace == null) return [];
    return _repo.getCollectionsByWorkspace(workspace.id);
  }

  /// Reloads the collection list from the repository.
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace == null) return [];
      return _repo.getCollectionsByWorkspace(workspace.id);
    });
  }

  /// Creates a new collection in the current workspace.
  ///
  /// [name] must not be empty. Returns the created [Collection] or `null`
  /// on failure (error is stored in [state]).
  Future<Collection?> createCollection({
    required String name,
    String description = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = AsyncValue.error(
        ArgumentError('Collection name cannot be empty'),
        StackTrace.current,
      );
      return null;
    }

    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) {
      state = AsyncValue.error(
        StateError('No workspace selected'),
        StackTrace.current,
      );
      return null;
    }

    try {
      final now = DateTime.now();
      final collection = Collection(
        id: '', // Assigned by the repository.
        workspaceId: workspace.id,
        name: trimmed,
        description: description.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final created = await _repo.createCollection(collection);

      // Append to the current list.
      state.whenData((list) {
        state = AsyncValue.data([...list, created]);
      });

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing collection.
  Future<void> updateCollection(Collection collection) async {
    try {
      final updated = await _repo.updateCollection(collection);
      state.whenData((list) {
        state = AsyncValue.data(
          list.map((c) => c.id == updated.id ? updated : c).toList(),
        );
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deletes a collection by its [id].
  ///
  /// If the deleted collection was the currently selected one, callers
  /// should null out [currentCollectionProvider] explicitly.
  Future<void> deleteCollection(String id) async {
    final previousState = state;

    // Optimistic removal.
    state.whenData((list) {
      state = AsyncValue.data(list.where((c) => c.id != id).toList());
    });

    try {
      await _repo.deleteCollection(id);
    } catch (e, st) {
      // Roll back on failure.
      state = previousState;
      state = AsyncValue.error(e, st);
    }
  }

  /// Adds a request to a collection at the given optional [index].
  ///
  /// If the request is already in the collection this is a no-op.
  Future<void> addRequestToCollection(
    String collectionId,
    String requestId, {
    int? index,
  }) async {
    await _repo.addRequestToCollection(collectionId, requestId, index: index);
    // Refresh the list to reflect the updated requestIds.
    await reload();
  }

  /// Removes a request from a collection.
  Future<void> removeRequestFromCollection(
    String collectionId,
    String requestId,
  ) async {
    await _repo.removeRequestFromCollection(collectionId, requestId);
    await reload();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the list of collections for the current workspace.
///
/// Rebuilds automatically when the workspace changes.
final collectionListProvider =
    AsyncNotifierProvider<CollectionListNotifier, List<Collection>>(
  CollectionListNotifier.new,
);

/// Tracks the currently selected [Collection] (e.g. for the collection detail view).
final currentCollectionProvider = StateProvider<Collection?>((ref) => null);