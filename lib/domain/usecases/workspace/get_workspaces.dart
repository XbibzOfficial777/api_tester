/// @file get_workspaces.dart
/// @brief Use case for retrieving all workspaces.
///
/// Returns the complete list of workspaces in the application,
/// sorted by most recently updated. This is a read-only operation
/// with no side effects.
library;

import '../../entities/workspace.dart';
import '../../repositories/workspace_repository.dart';
import '../usecase.dart';

/// Retrieves all workspaces from the repository.
///
/// This use case requires no parameters and returns a list of all
/// available workspaces. The presentation layer typically displays
/// these in a sidebar or list view.
class GetWorkspaces extends UseCase<List<Workspace>, NoParams> {
  /// The workspace repository used to fetch data.
  final WorkspaceRepository _repository;

  /// Creates a new [GetWorkspaces] use case.
  ///
  /// [repository] - The workspace repository implementation.
  GetWorkspaces(this._repository);

  /// Fetches and returns all workspaces.
  ///
  /// Returns an empty list if no workspaces have been created yet.
  @override
  Future<List<Workspace>> call(NoParams params) async {
    return _repository.getWorkspaces();
  }
}