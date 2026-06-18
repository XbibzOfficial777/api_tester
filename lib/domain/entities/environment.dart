/// @file environment.dart
/// @brief Domain entity for an environment configuration.
///
/// An environment defines a set of variables (key-value pairs) that can
/// be referenced in requests using the {{variableName}} syntax. Typical
/// environments include "Development", "Staging", and "Production", each
/// with their own base URLs, API keys, and other configuration values.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'environment_variable.dart';

part 'environment.freezed.dart';
part 'environment.g.dart';

/// A named set of variables for a specific deployment context.
///
/// Environments allow switching between different API configurations
/// (e.g., dev vs. production) without modifying individual requests.
/// Only one environment per workspace can be active at a time.
/// A global environment can be used to share variables across workspaces.
@freezed
class Environment with _$Environment {
  /// Creates a new [Environment] instance.
  ///
  /// [id] - Unique identifier (UUID format).
  /// [workspaceId] - The workspace this environment belongs to.
  /// [name] - Environment name (e.g., "Development", "Staging", "Production").
  /// [variables] - List of variable definitions for this environment.
  /// [isGlobal] - Whether this is a global environment shared across workspaces.
  /// [isActive] - Whether this is the currently active environment for the workspace.
  /// [createdAt] - Timestamp when this environment was created.
  /// [updatedAt] - Timestamp when this environment was last modified.
  const factory Environment({
    required String id,
    required String workspaceId,
    required String name,
    @Default([]) List<EnvironmentVariable> variables,
    @Default(false) bool isGlobal,
    @Default(false) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Environment;

  /// Deserializes an [Environment] from a JSON map.
  factory Environment.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentFromJson(json);
}