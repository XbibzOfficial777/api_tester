/// @file request_repository.dart
/// @brief Repository interface for [ApiRequest] entity CRUD and execution.
///
/// Extends basic CRUD with request execution ([sendRequest]) and
/// convenience methods for querying requests by workspace or collection.
library;

import '../entities/api_request.dart';
import '../entities/api_response.dart';

/// Abstract repository providing CRUD operations and HTTP execution
/// for [ApiRequest] entities.
///
/// This is the primary repository that the data layer implements
/// for managing and executing API requests.
abstract class RequestRepository {
  /// Retrieves a single request by its unique identifier.
  ///
  /// [id] - The UUID of the request to retrieve.
  ///
  /// Throws [NotFoundException] if no request with the given [id] exists.
  Future<ApiRequest> getRequest(String id);

  /// Creates a new request and persists it to storage.
  ///
  /// [request] - The request entity to create.
  ///
  /// Returns the persisted request, potentially with updated fields.
  Future<ApiRequest> createRequest(ApiRequest request);

  /// Updates an existing request with new values.
  ///
  /// [request] - The request entity with updated fields.
  ///
  /// Returns the updated request with a refreshed [updatedAt] timestamp.
  Future<ApiRequest> updateRequest(ApiRequest request);

  /// Permanently deletes a request by its unique identifier.
  ///
  /// [id] - The UUID of the request to delete.
  ///
  /// Also removes the request from any collections it belongs to.
  Future<void> deleteRequest(String id);

  /// Retrieves all requests belonging to a specific workspace.
  ///
  /// [workspaceId] - The UUID of the workspace to filter by.
  ///
  /// Returns requests that are not assigned to any collection,
  /// sorted by most recently updated first.
  Future<List<ApiRequest>> getRequestsByWorkspace(String workspaceId);

  /// Retrieves all requests belonging to a specific collection.
  ///
  /// [collectionId] - The UUID of the collection to filter by.
  ///
  /// Returns requests in the order defined by the collection's
  /// [requestIds] list.
  Future<List<ApiRequest>> getRequestsByCollection(String collectionId);

  /// Sends the given HTTP request and returns the response.
  ///
  /// [request] - The fully configured request to execute. Environment
  /// variables should already be resolved before calling this method.
  ///
  /// Returns an [ApiResponse] containing the server's response data
  /// and performance metrics.
  ///
  /// Throws [NetworkException] if the request cannot be sent due to
  /// network errors, timeouts, or DNS resolution failures.
  /// Throws [CertificateException] if SSL verification fails.
  Future<ApiResponse> sendRequest(ApiRequest request);

  /// Retrieves recently used endpoint URLs for autocomplete suggestions.
  ///
  /// Returns a list of URL strings that have been used in recent requests,
  /// ordered by most recent usage. Typically limited to the 20 most recent.
  Future<List<String>> getRecentEndpoints();
}