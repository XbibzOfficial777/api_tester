/// Mapper that converts between [EnvironmentTableData] (Drift data-class)
/// and the domain [Environment] entity.
///
/// The [EnvironmentTableData.variables] column is stored as a JSON-encoded
/// list of `{key, value, enabled}` objects; this mapper handles the
/// serialisation / deserialisation.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/environment.dart';
import '../../../domain/entities/key_value.dart';
import '../datasources/local/database/tables.dart';

/// Stateless helper providing bidirectional mapping for [Environment].
class EnvironmentMapper {
  EnvironmentMapper._();

  // ---------------------------------------------------------------------------
  // Data → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [EnvironmentTableData] row into a domain [Environment].
  static Environment toEntity(EnvironmentTableData data) {
    return Environment(
      id: data.id,
      workspaceId: data.workspaceId,
      name: data.name,
      variables: _parseKeyValueList(data.variables),
      isGlobal: data.isGlobal,
      isActive: data.isActive,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Converts a list of Drift rows into a list of domain entities.
  static List<Environment> toEntityList(List<EnvironmentTableData> data) {
    return data.map(toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Domain → Data
  // ---------------------------------------------------------------------------

  /// Converts a domain [Environment] into a Drift [EnvironmentsCompanion].
  static EnvironmentsCompanion fromEntity(Environment entity) {
    return EnvironmentsCompanion(
      id: Value(entity.id),
      workspaceId: Value(entity.workspaceId),
      name: Value(entity.name),
      variables: Value(_encodeKeyValueList(entity.variables)),
      isGlobal: Value(entity.isGlobal),
      isActive: Value(entity.isActive),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a JSON-encoded string into a [List<KeyValue>].
  static List<KeyValue> _parseKeyValueList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((item) {
            final map = item as Map<String, dynamic>;
            return KeyValue(
              key: map['key'] as String? ?? '',
              value: map['value'] as String? ?? '',
              enabled: map['enabled'] as bool? ?? true,
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialises a [List<KeyValue>] into a JSON string.
  static String _encodeKeyValueList(List<KeyValue> pairs) {
    final encoded = pairs
        .map((kv) => {
              'key': kv.key,
              'value': kv.value,
              'enabled': kv.enabled,
            })
        .toList();
    return json.encode(encoded);
  }
}