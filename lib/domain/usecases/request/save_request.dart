/// @file save_request.dart
/// @brief Use case for creating or updating an API request.
///
/// Determines whether to create or update based on whether the request
/// already has a non-empty ID. Sets the [updatedAt] timestamp automatically.
library;

import '../../entities/api_request.dart';
import '../../repositories/request_repository.dart';
import '../usecase.dart';

/// Parameters required to save (create or update) a request.
class SaveRequestParams {
  /// The request to save. If [id] is empty, a new request will be created.
  /// Otherwise, the existing request with that ID will be updated.
  final ApiRequest request;

  /// Creates parameter object for saving a request.
  ///
  /// [request] - The API request entity to persist.
  const SaveRequestParams({required this.request});
}

/// Creates a new request or updates an existing one.
///
/// If the request's [id] is empty, this use case delegates to the
/// repository's create method. Otherwise, it delegates to the update
/// method. The [updatedAt] timestamp is always refreshed.
class SaveRequest extends UseCase<ApiRequest, SaveRequestParams> {
  /// The request repository used for persistence.
  final RequestRepository _repository;

  /// Creates a new [SaveRequest] use case.
  ///
  /// [repository] - The request repository implementation.
  SaveRequest(this._repository);

  /// Saves the request (creates or updates).
  ///
  /// [params] - Contains the request to save.
  ///
  /// Returns the persisted request with updated timestamps.
  @override
  Future<ApiRequest> call(SaveRequestParams params) async {
    final request = params.request;

    // Update the timestamp before saving.
    final updatedRequest = request.copyWith(
      updatedAt: DateTime.now(),
    );

    // Decide between create and update based on whether an ID exists.
    if (request.id.isEmpty) {
      return _repository.createRequest(updatedRequest);
    } else {
      return _repository.updateRequest(updatedRequest);
    }
  }
}