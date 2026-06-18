/// Mapper that converts between [ApiRequestTableData] (Drift data-class)
/// and the domain [ApiRequest] entity.
///
/// Because several columns (headers, queryParams, formData) are stored as
/// JSON strings, this mapper handles the serialisation / deserialisation
/// automatically.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/api_request.dart';
import '../../../domain/entities/body_type.dart';
import '../../../domain/entities/key_value.dart';
import '../datasources/local/database/app_database.dart';

/// Stateless helper providing bidirectional mapping for [ApiRequest].
class RequestMapper {
  RequestMapper._();

  // ---------------------------------------------------------------------------
  // Data → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [ApiRequestTableData] row into a domain [ApiRequest].
  ///
  /// JSON columns are parsed into typed lists. If parsing fails an empty
  /// list is returned rather than propagating an exception.
  static ApiRequest toEntity(ApiRequestTableData data) {
    return ApiRequest(
      id: data.id,
      workspaceId: data.workspaceId,
      collectionId: data.collectionId,
      name: data.name,
      description: data.description,
      method: HttpMethod.fromString(data.method),
      url: data.url,
      headers: _parseKeyValueList(data.headers),
      queryParams: _parseKeyValueList(data.queryParams),
      bodyType: BodyType.fromDbString(data.bodyType),
      bodyContent: data.bodyContent,
      formData: _parseKeyValueList(data.formData),
      binaryFilePath: data.binaryFilePath,
      preRequestScript: data.preRequestScript,
      useProxy: data.useProxy,
      proxyHost: data.proxyHost,
      proxyPort: data.proxyPort,
      proxyType: data.proxyType != null
          ? ProxyType.fromString(data.proxyType!)
          : null,
      timeoutSeconds: data.timeoutSeconds,
      followRedirects: data.followRedirects,
      verifySsl: data.verifySsl,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  /// Converts a list of Drift rows into a list of domain entities.
  static List<ApiRequest> toEntityList(List<ApiRequestTableData> data) {
    return data.map(toEntity).toList();
  }

  // ---------------------------------------------------------------------------
  // Domain → Data
  // ---------------------------------------------------------------------------

  /// Converts a domain [ApiRequest] into a Drift [ApiRequestsCompanion].
  ///
  /// List-valued fields are serialised to JSON strings before storage.
  static ApiRequestsCompanion fromEntity(ApiRequest entity) {
    return ApiRequestsCompanion(
      id: Value(entity.id),
      workspaceId: Value(entity.workspaceId),
      collectionId: Value(entity.collectionId),
      name: Value(entity.name),
      description: Value(entity.description),
      method: Value(entity.method.name),
      url: Value(entity.url),
      headers: Value(_encodeKeyValueList(entity.headers)),
      queryParams: Value(_encodeKeyValueList(entity.queryParams)),
      bodyType: Value(entity.bodyType.toDbString()),
      bodyContent: Value(entity.bodyContent),
      formData: Value(_encodeKeyValueList(entity.formData)),
      binaryFilePath: Value(entity.binaryFilePath),
      preRequestScript: Value(entity.preRequestScript),
      useProxy: Value(entity.useProxy),
      proxyHost: Value(entity.proxyHost),
      proxyPort: Value(entity.proxyPort),
      proxyType: Value(entity.proxyType?.name),
      timeoutSeconds: Value(entity.timeoutSeconds),
      followRedirects: Value(entity.followRedirects),
      verifySsl: Value(entity.verifySsl),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a JSON-encoded string into a [List<KeyValue>].
  ///
  /// Returns an empty list when:
  /// - [jsonString] is empty or `null`.
  /// - The JSON is malformed.
  /// - An element is missing required fields.
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
      // Malformed JSON – return an empty list instead of crashing.
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