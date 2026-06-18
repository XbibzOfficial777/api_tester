/// @file environment_repository.dart
/// @brief Repository interface for [Environment] entity CRUD and variable resolution.
///
/// Provides CRUD operations for environments plus the critical ability to
/// resolve {{variable}} placeholders in text strings using the active
/// environment's variables.
library;

import '../entities/environment.dart';

/// Abstract repository providing CRUD, activation, and variable resolution
/// operations for [Environment] entities.
abstract class EnvironmentRepository {
  /// Retrieves a single environment by its unique identifier.
  ///
  /// [id] - The UUID of the environment to retrieve.
  Future<Environment> getEnvironment(String id);

  /// Retrieves all environments belonging to a specific workspace.
  ///
  /// [workspaceId] - The UUID of the workspace to filter by.
  ///
  /// Includes both workspace-specific and global environments.
  Future<List<Environment>> getEnvironmentsByWorkspace(String workspaceId);

  /// Creates a new environment and persists it to storage.
  ///
  /// [environment] - The environment entity to create.
  ///
  /// Returns the persisted environment with any server-generated fields.
  Future<Environment> createEnvironment(Environment environment);

  /// Updates an existing environment with new values.
  ///
  /// [environment] - The environment entity with updated fields.
  ///
  /// If [variables] changed, the new values take effect immediately
  /// for subsequent variable resolution calls.
  Future<Environment> updateEnvironment(Environment environment);

  /// Permanently deletes an environment by its unique identifier.
  ///
  /// [id] - The UUID of the environment to delete.
  ///
  /// If this was the active environment, no environment will be active
  /// after deletion.
  Future<void> deleteEnvironment(String id);

  /// Retrieves the currently active environment for a workspace.
  ///
  /// [workspaceId] - The UUID of the workspace.
  ///
  /// Returns null if no environment is currently active for the workspace.
  Future<Environment?> getActiveEnvironment(String workspaceId);

  /// Sets the active environment for a workspace.
  ///
  /// [workspaceId] - The UUID of the workspace.
  /// [environmentId] - The UUID of the environment to activate.
  ///
  /// Deactivates any previously active environment for the workspace.
  /// Throws [NotFoundException] if the environment does not exist.
  Future<void> setActiveEnvironment(String workspaceId, String environmentId);

  /// Resolves all {{variable}} placeholders in the input string.
  ///
  /// [workspaceId] - The UUID of the workspace (to find the active environment).
  /// [input] - The string containing {{variableName}} placeholders.
  ///
  /// Returns the input string with all enabled variable references replaced
  /// by their corresponding values. Unresolved placeholders (unknown variables
  /// or no active environment) are left as-is.
  ///
  /// Example:
  /// ```dart
  /// // Active environment has: base_url = "https://api.example.com"
  /// final resolved = await resolveVariables('ws123', '{{base_url}}/users');
  /// // Returns: "https://api.example.com/users"
  /// ```
  Future<String> resolveVariables(String workspaceId, String input);
}