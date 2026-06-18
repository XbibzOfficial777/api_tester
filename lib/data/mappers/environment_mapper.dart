/// Mapper that converts between [EnvironmentTableData] (Drift data-class)
/// and the domain [Environment] entity.
///
/// The [EnvironmentTableData.variables] column is stored as a JSON-encoded
/// list of `{key, value, type, description, enabled}` objects; this mapper
/// handles the serialisation / deserialisation.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/environment.dart';
import '../../../domain/entities/environment_variable.dart';
import '../datasources/local/database/app_database.dart';
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
      variables: _parseEnvironmentVariables(data.variables),
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
      variables: Value(_encodeEnvironmentVariables(entity.variables)),
      isGlobal: Value(entity.isGlobal),
      isActive: Value(entity.isActive),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a JSON-encoded string into a [List<EnvironmentVariable>].
  ///
  /// Returns an empty list when:
  /// - [jsonString] is empty or `null`.
  /// - The JSON is malformed.
  /// - An element is missing required fields.
  ///
  /// The database stores `enabled` while the entity uses `isEnabled`.
  /// If a `type` field is missing it defaults to [VariableType.string];
  /// if `description` is missing it defaults to an empty string.
  static List<EnvironmentVariable> _parseEnvironmentVariables(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((item) {
            final map = item as Map<String, dynamic>;

            // Parse the type – fall back to string for legacy / missing values.
            VariableType type = VariableType.string;
            final rawType = map['type'];
            if (rawType is String) {
              type = VariableType.values.firstWhere(
                (e) => e.name == rawType,
                orElse: () => VariableType.string,
              );
            }

            return EnvironmentVariable(
              key: map['key'] as String? ?? '',
              value: map['value'] as String? ?? '',
              type: type,
              description: map['description'] as String? ?? '',
              isEnabled: map['enabled'] as bool? ?? true,
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialises a [List<EnvironmentVariable>] into a JSON string.
  static String _encodeEnvironmentVariables(List<EnvironmentVariable> variables) {
    final encoded = variables
        .map((v) => {
              'key': v.key,
              'value': v.value,
              'type': v.type.name,
              'description': v.description,
              'enabled': v.isEnabled,
            })
        .toList();
    return json.encode(encoded);
  }
}
