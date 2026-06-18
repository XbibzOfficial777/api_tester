/// @file usecase.dart
/// @brief Base class for all use cases in the application.
///
/// Follows the Clean Architecture pattern where each use case represents
/// a single action the user can perform. The generic [Type] parameter
/// specifies the return type, and [Params] specifies the input parameters.
///
/// Example usage:
/// ```dart
/// class GetWorkspaces extends UseCase<List<Workspace>, NoParams> {
///   final WorkspaceRepository repository;
///   GetWorkspaces(this.repository);
///
///   @override
///   Future<List<Workspace>> call(NoParams params) async {
///     return repository.getWorkspaces();
///   }
/// }
/// ```
library;

/// Base class for all use cases.
///
/// Subclasses implement the [call] method which contains the business
/// logic for a specific user action. Use cases are typically injected
/// via GetIt and called from presentation layer (BLoC/Notifier).
///
/// [Type] - The type of value returned by this use case.
/// [Params] - The type of parameter object required by this use case.
/// Use [NoParams] for use cases that require no input.
abstract class UseCase<Type, Params> {
  /// Executes the use case with the given parameters.
  ///
  /// [params] - The input parameters for the use case.
  ///
  /// Returns the result of the use case execution.
  /// May throw domain exceptions or propagate infrastructure errors.
  Future<Type> call(Params params);
}

/// Marker class for use cases that require no parameters.
///
/// Use this as the [Params] type parameter when a use case needs
/// no input from the caller.
class NoParams {
  /// Private constructor to prevent instantiation.
  const NoParams._();
}