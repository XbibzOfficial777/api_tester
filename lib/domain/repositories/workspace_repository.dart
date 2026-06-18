/// @file workspace_repository.dart
/// @brief Repository interface for [Workspace] entity CRUD operations.
///
/// Defines the contract that any data source implementation must fulfill
/// for workspace management. Implementations may use SQLite (via Drift),
/// shared preferences, or a remote backend.
library;

import '../entities/workspace.dart';

/// Abstract repository providing CRUD operations for [Workspace] entities.
///
/// This repository is the single source of truth for workspace data
/// within the domain layer. The data layer provides concrete
/// implementations.
abstract class WorkspaceRepository {
  /// Retrieves all workspaces in the application.
  ///
  /// Returns an unmodifiable list of all available workspaces,
  /// sorted by most recently updated first.
  ///
  /// Returns an empty list if no workspaces exist.
  Future<List<Workspace>> getWorkspaces();

  /// Retrieves a single workspace by its unique identifier.
  ///
  /// [id] - The UUID of the workspace to retrieve.
  ///
  /// Throws [NotFoundException] if no workspace with the given [id] exists.
  Future<Workspace> getWorkspace(String id);

  /// Creates a new workspace and persists it to storage.
  ///
  /// [workspace] - The workspace entity to create. The [id], [createdAt],
  /// and [updatedAt] fields should be set before calling this method.
  ///
  /// Returns the persisted workspace, which may have updated fields
  /// (e.g., generated ID if not provided).
  Future<Workspace> createWorkspace(Workspace workspace);

  /// Updates an existing workspace with new values.
  ///
  /// [workspace] - The workspace entity with updated fields. The [id]
  /// must match an existing workspace.
  ///
  /// Returns the updated workspace with a refreshed [updatedAt] timestamp.
  ///
  /// Throws [NotFoundException] if no workspace with the given ID exists.
  Future<Workspace> updateWorkspace(Workspace workspace);

  /// Permanently deletes a workspace and all associated data.
  ///
  /// [id] - The UUID of the workspace to delete.
  ///
  /// Implementations should cascade the delete to all associated
  /// collections, environments, requests, and history entries.
  Future<void> deleteWorkspace(String id);
}