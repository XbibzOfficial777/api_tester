/// @file delete_workspace.dart
/// @brief Use case for deleting a workspace and all its associated data.
///
/// Delegates directly to the repository, which is responsible for
/// cascading the deletion to all associated collections, environments,
/// requests, and history entries.
library;

import '../../repositories/workspace_repository.dart';
import '../usecase.dart';

/// Parameters required to delete a workspace.
class DeleteWorkspaceParams {
  /// The UUID of the workspace to delete.
  final String id;

  /// Creates parameter object for workspace deletion.
  ///
  /// [id] - Must be a valid workspace UUID.
  const DeleteWorkspaceParams({required this.id});
}

/// Deletes a workspace by its unique identifier.
///
/// This is an irreversible operation. The repository implementation
/// must ensure all associated data (collections, environments, requests,
/// history) is also deleted to maintain data integrity.
class DeleteWorkspace extends UseCase<void, DeleteWorkspaceParams> {
  /// The workspace repository used to perform the deletion.
  final WorkspaceRepository _repository;

  /// Creates a new [DeleteWorkspace] use case.
  ///
  /// [repository] - The workspace repository implementation.
  DeleteWorkspace(this._repository);

  /// Deletes the workspace with the given ID.
  ///
  /// [params] - Contains the ID of the workspace to delete.
  @override
  Future<void> call(DeleteWorkspaceParams params) async {
    await _repository.deleteWorkspace(params.id);
  }
}