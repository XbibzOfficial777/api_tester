/// @file collection.dart
/// @brief Domain entity for organizing requests into logical groups.
///
/// A collection groups related API requests together, enabling
/// sequential execution (collection runner) and organized navigation.
/// Collections support configurable delays between requests and
/// error-handling behavior during batch runs.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'collection.freezed.dart';
part 'collection.g.dart';

/// An ordered group of related API requests.
///
/// Collections enable users to organize requests by feature, API version,
/// or workflow. The [requestIds] list preserves the user-defined order
/// and supports reordering. Collections can be executed sequentially
/// with the collection runner feature.
@freezed
class Collection with _$Collection {
  /// Creates a new [Collection] instance.
  ///
  /// [id] - Unique identifier (UUID format).
  /// [workspaceId] - The workspace this collection belongs to.
  /// [name] - Display name for the collection.
  /// [description] - Optional description of the collection's purpose.
  /// [requestIds] - Ordered list of request IDs contained in this collection.
  /// [delayBetweenRequestsMs] - Delay in milliseconds between sequential requests. Defaults to 0.
  /// [stopOnError] - Whether to abort the collection run on first failure. Defaults to false.
  /// [createdAt] - Timestamp when this collection was created.
  /// [updatedAt] - Timestamp when this collection was last modified.
  const factory Collection({
    required String id,
    required String workspaceId,
    required String name,
    @Default('') String description,
    @Default([]) List<String> requestIds,
    @Default(0) int delayBetweenRequestsMs,
    @Default(false) bool stopOnError,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Collection;

  /// Deserializes a [Collection] from a JSON map.
  factory Collection.fromJson(Map<String, dynamic> json) =>
      _$CollectionFromJson(json);
}