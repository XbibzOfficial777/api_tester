/// @file create_workspace.dart
/// @brief Use case for creating a new workspace.
///
/// Validates that the workspace name is not empty before delegating
/// to the repository. This is the only business rule for workspace
/// creation at the domain level.
library;

import '../../entities/workspace.dart';
import '../../repositories/workspace_repository.dart';
import '../usecase.dart';

/// Parameters required to create a new workspace.
class CreateWorkspaceParams {
  /// The display name for the new workspace. Must not be empty.
  final String name;

  /// An optional description of the workspace's purpose.
  final String description;

  /// Creates parameter object for workspace creation.
  ///
  /// [name] - Must be a non-empty string.
  /// [description] - Defaults to an empty string.
  const CreateWorkspaceParams({
    required this.name,
    this.description = '',
  });
}

/// Creates a new workspace after validating the name.
///
/// Enforces the business rule that workspace names cannot be empty
/// or consist only of whitespace.
class CreateWorkspace extends UseCase<Workspace, CreateWorkspaceParams> {
  /// The workspace repository used to persist the new workspace.
  final WorkspaceRepository _repository;

  /// Creates a new [CreateWorkspace] use case.
  ///
  /// [repository] - The workspace repository implementation.
  CreateWorkspace(this._repository);

  /// Validates the name and creates the workspace.
  ///
  /// Throws [ArgumentError] if [params.name] is empty or whitespace-only.
  @override
  Future<Workspace> call(CreateWorkspaceParams params) async {
    // Validate that the workspace name is not empty.
    if (params.name.trim().isEmpty) {
      throw ArgumentError('Workspace name cannot be empty');
    }

    final now = DateTime.now();
    final workspace = Workspace(
      id: '', // Will be assigned by the repository implementation.
      name: params.name.trim(),
      description: params.description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    return _repository.createWorkspace(workspace);
  }
}