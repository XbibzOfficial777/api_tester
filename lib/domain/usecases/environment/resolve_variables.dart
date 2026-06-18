/// @file resolve_variables.dart
/// @brief Use case for resolving environment variable placeholders in text.
///
/// Provides a convenient way to substitute all {{variableName}} patterns
/// in any string with their corresponding values from the active environment.
library;

import '../../repositories/environment_repository.dart';
import '../usecase.dart';

/// Parameters required for variable resolution.
class ResolveVariablesParams {
  /// The workspace ID used to find the active environment.
  final String workspaceId;

  /// The input string containing {{variableName}} placeholders.
  final String input;

  /// Creates parameter object for variable resolution.
  ///
  /// [workspaceId] - The UUID of the workspace.
  /// [input] - The string with placeholders to resolve.
  const ResolveVariablesParams({
    required this.workspaceId,
    required this.input,
  });
}

/// Resolves {{variable}} placeholders using the active environment.
///
/// Delegates to [EnvironmentRepository.resolveVariables] and provides
/// a clean use case interface for the presentation layer.
class ResolveVariables extends UseCase<String, ResolveVariablesParams> {
  /// The environment repository for variable resolution.
  final EnvironmentRepository _repository;

  /// Creates a new [ResolveVariables] use case.
  ///
  /// [repository] - The environment repository implementation.
  ResolveVariables(this._repository);

  /// Resolves all variable placeholders in the input string.
  ///
  /// [params] - Contains the workspace ID and input string.
  ///
  /// Returns the input string with all {{variable}} references replaced
  /// by their values from the active environment. Unknown variables are
  /// left as-is.
  @override
  Future<String> call(ResolveVariablesParams params) async {
    return _repository.resolveVariables(
      params.workspaceId,
      params.input,
    );
  }
}