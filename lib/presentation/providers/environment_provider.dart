/// @file environment_provider.dart
/// @brief Riverpod providers for environment and variable management.
///
/// Provides the environment list for the current workspace, the active
/// environment, and methods to CRUD environments, set the active one,
/// and resolve {{variable}} placeholders.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/environment.dart';
import 'package:api_tester/domain/entities/environment_variable.dart';
import 'package:api_tester/domain/repositories/environment_repository.dart';
import 'package:api_tester/presentation/providers/workspace_provider.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the async state of the environment list for the current workspace.
///
/// Rebuilds automatically when the current workspace changes. Exposes
/// mutation methods for CRUD and activation.
class EnvironmentListNotifier extends AsyncNotifier<List<Environment>> {
  EnvironmentRepository get _repo => getIt<EnvironmentRepository>();

  @override
  Future<List<Environment>> build() async {
    // Watch the current workspace so we reload on workspace change.
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace == null) return [];
    return _repo.getEnvironmentsByWorkspace(workspace.id);
  }

  /// Reloads environments from the repository.
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace == null) return [];
      return _repo.getEnvironmentsByWorkspace(workspace.id);
    });
  }

  /// Creates a new environment in the current workspace.
  ///
  /// Returns the created [Environment] or `null` on failure.
  Future<Environment?> createEnvironment({
    required String name,
    List<EnvironmentVariable>? variables,
    bool isGlobal = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = AsyncValue.error(
        ArgumentError('Environment name cannot be empty'),
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
      final environment = Environment(
        id: '', // Assigned by the repository.
        workspaceId: workspace.id,
        name: trimmed,
        variables: variables ?? [],
        isGlobal: isGlobal,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      final created = await _repo.createEnvironment(environment);

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

  /// Updates an existing environment.
  ///
  /// After a successful update the list and active environment providers
  /// are refreshed so the UI stays consistent.
  Future<void> updateEnvironment(Environment environment) async {
    try {
      final updated = await _repo.updateEnvironment(environment);
      state.whenData((list) {
        state = AsyncValue.data(
          list.map((e) => e.id == updated.id ? updated : e).toList(),
        );
      });

      // If the updated environment is the active one, refresh it too.
      final active = ref.read(activeEnvironmentProvider);
      if (active != null && active.id == updated.id) {
        ref.read(activeEnvironmentProvider.notifier).state = updated;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deletes an environment by its [id].
  ///
  /// If the deleted environment was active, [activeEnvironmentProvider]
  /// is set to `null`.
  Future<void> deleteEnvironment(String id) async {
    final previousState = state;

    // Optimistic removal.
    state.whenData((list) {
      state = AsyncValue.data(list.where((e) => e.id != id).toList());
    });

    try {
      await _repo.deleteEnvironment(id);

      // Clear the active environment if it was the deleted one.
      final active = ref.read(activeEnvironmentProvider);
      if (active != null && active.id == id) {
        ref.read(activeEnvironmentProvider.notifier).state = null;
      }
    } catch (e, st) {
      // Roll back on failure.
      state = previousState;
      state = AsyncValue.error(e, st);
    }
  }

  /// Sets the active environment for the current workspace.
  ///
  /// Deactivates any previously active environment.
  Future<void> setActiveEnvironment(String environmentId) async {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) {
      throw StateError('No workspace selected');
    }

    await _repo.setActiveEnvironment(workspace.id, environmentId);

    // Fetch the newly active environment.
    final active = await _repo.getEnvironment(environmentId);
    ref.read(activeEnvironmentProvider.notifier).state = active;

    // Update the isActive flags in the list.
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((e) => e.copyWith(isActive: e.id == environmentId)).toList(),
      );
    });
  }

  /// Resolves all {{variable}} placeholders in the given [input] string.
  ///
  /// Uses the active environment of the current workspace. Unknown or
  /// unresolved placeholders are left as-is.
  Future<String> resolveVariables(String input) async {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return input;
    return _repo.resolveVariables(workspace.id, input);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the list of environments for the current workspace.
///
/// Rebuilds automatically when the workspace changes.
final environmentListProvider =
    AsyncNotifierProvider<EnvironmentListNotifier, List<Environment>>(
  EnvironmentListNotifier.new,
);

/// Tracks the currently active [Environment] for the workspace.
///
/// `null` when no environment is active. Updated by
/// [EnvironmentListNotifier.setActiveEnvironment].
final activeEnvironmentProvider = StateProvider<Environment?>((ref) => null);