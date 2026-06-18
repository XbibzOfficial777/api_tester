/// Mapper that converts between [CollectionTableData] (Drift data-class)
/// and the domain [Collection] entity.
///
/// The [CollectionTableData.requestIds] column is stored as a JSON-encoded
/// `List<String>`; this mapper handles serialisation / deserialisation.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/collection.dart';
import '../datasources/local/database/tables.dart';

/// Stateless helper providing bidirectional mapping for [Collection].
class CollectionMapper {
  CollectionMapper._();

  // ---------------------------------------------------------------------------
  // Data → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [CollectionTableData] row into a domain [Collection].
  static Collection toEntity(CollectionTableData data) {
    return Collection(
      id: data.id,
      workspaceId: data.workspaceId,
      name: data.name,
      description: data.description,
      requestIds: _parseStringList(data.requestIds),
      delayMs: data.delayMs,
      stopOnError: data.stopOnError,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Converts a list of Drift rows into a list of domain entities.
  static List<Collection> toEntityList(List<CollectionTableData> data) {
    return data.map(toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Domain → Data
  // ---------------------------------------------------------------------------

  /// Converts a domain [Collection] into a Drift [CollectionsCompanion].
  static CollectionsCompanion fromEntity(Collection entity) {
    return CollectionsCompanion(
      id: Value(entity.id),
      workspaceId: Value(entity.workspaceId),
      name: Value(entity.name),
      description: Value(entity.description),
      requestIds: Value(_encodeStringList(entity.requestIds)),
      delayMs: Value(entity.delayMs),
      stopOnError: Value(entity.stopOnError),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a JSON-encoded string into a `List<String>`.
  ///
  /// Gracefully handles empty strings, `null`, and malformed JSON by
  /// returning an empty list.
  static List<String> _parseStringList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialises a `List<String>` into a JSON array string.
  static String _encodeStringList(List<String> values) {
    return json.encode(values);
  }
}