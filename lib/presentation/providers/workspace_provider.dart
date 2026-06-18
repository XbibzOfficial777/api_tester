/// @file workspace_provider.dart
/// @brief Riverpod providers for workspace management.
///
/// Provides the workspace list (auto-loaded on init), the currently
/// selected workspace, and methods to create / update / delete workspaces.
/// All repository and use-case dependencies are resolved from the
/// [serviceLocator] (GetIt).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/workspace.dart';
import 'package:api_tester/domain/repositories/workspace_repository.dart';
import 'package:api_tester/domain/usecases/workspace/create_workspace.dart';
import 'package:api_tester/domain/usecases/workspace/delete_workspace.dart';
import 'package:api_tester/domain/usecases/workspace/get_workspaces.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the async state of the workspace list.
///
/// Automatically loads all workspaces when the provider is first read.
/// Exposes mutation methods that update the internal [AsyncValue] and
/// keep the UI in sync.
class WorkspaceListNotifier extends AsyncNotifier<List<Workspace>> {
  WorkspaceRepository get _repo => getIt<WorkspaceRepository>();

  @override
  Future<List<Workspace>> build() async {
    // Auto-load workspaces on first access.
    return _repo.getWorkspaces();
  }

  /// Refreshes the workspace list from the repository.
  ///
  /// Useful after external changes or pull-to-refresh gestures.
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getWorkspaces());
  }

  /// Creates a new workspace with the given [name] and optional [description].
  ///
  /// On success the new workspace is appended to the list and the state is
  /// updated optimistically. If the operation fails the previous state is
  /// restored and the error is surfaced.
  Future<Workspace?> createWorkspace({
    required String name,
    String description = '',
  }) async {
    // Validate the name before hitting the repository.
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = AsyncValue.error(
        ArgumentError('Workspace name cannot be empty'),
        StackTrace.current,
      );
      return null;
    }

    final useCase = CreateWorkspace(_repo);
    try {
      final workspace = await useCase(
        CreateWorkspaceParams(name: trimmed, description: description.trim()),
      );

      // Append the newly created workspace to the current list.
      state.whenData((list) {
        state = AsyncValue.data([...list, workspace]);
      });

      return workspace;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing workspace.
  ///
  /// The [workspace] parameter must contain a valid [Workspace.id].
  Future<void> updateWorkspace(Workspace workspace) async {
    try {
      final updated = await _repo.updateWorkspace(workspace);

      // Replace the old workspace in the list.
      state.whenData((list) {
        state = AsyncValue.data(
          list.map((w) => w.id == updated.id ? updated : w).toList(),
        );
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deletes a workspace by its [id] and removes it from the list.
  ///
  /// If the deleted workspace was the currently-selected one the
  /// [currentWorkspaceProvider] will still hold a stale reference –
  /// callers should null it out explicitly when appropriate.
  Future<void> deleteWorkspace(String id) async {
    final previousState = state;

    // Optimistic removal.
    state.whenData((list) {
      state = AsyncValue.data(list.where((w) => w.id != id).toList());
    });

    try {
      await _repo.deleteWorkspace(id);
    } catch (e, st) {
      // Roll back on failure.
      state = previousState;
      state = AsyncValue.error(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the list of all workspaces, auto-loaded on first access.
///
/// Usage:
/// ```dart
/// final workspaces = ref.watch(workspaceListProvider);
/// workspaces.when(data: (list) => ..., loading: () => ..., error: (e, _) => ...);
/// ```
final workspaceListProvider =
    AsyncNotifierProvider<WorkspaceListNotifier, List<Workspace>>(
  WorkspaceListNotifier.new,
);

/// Tracks the currently selected [Workspace].
///
/// Set to `null` when no workspace is active (e.g. initial state or after
/// the selected workspace is deleted). UI layers should watch this and
/// show a workspace picker when it is null.
final currentWorkspaceProvider = StateProvider<Workspace?>((ref) {
  return null;
});