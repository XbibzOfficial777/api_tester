/// Mapper that converts between [ApiRequestTableData] (Drift data-class)
/// and the domain [ApiRequest] entity.
///
/// Because several columns (headers, queryParams, formData) are stored as
/// JSON strings, this mapper handles the serialisation / deserialisation
/// automatically.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/api_request.dart';
import '../../../domain/entities/form_data_item.dart';
import '../../../domain/entities/key_value_item.dart';
import '../datasources/local/database/app_database.dart';

/// Stateless helper providing bidirectional mapping for [ApiRequest].
class RequestMapper {
  RequestMapper._();

  static const _uuid = Uuid();

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
      description: data.description ?? '',
      method: HttpMethod.values.firstWhere(
        (e) => e.name == data.method,
        orElse: () => HttpMethod.get,
      ),
      url: data.url,
      headers: _parseKeyValueItemList(data.headers),
      queryParams: _parseKeyValueItemList(data.queryParams),
      bodyType: BodyTypeX.fromDbString(data.bodyType),
      bodyContent: data.bodyContent ?? '',
      formDataItems: _parseFormDataList(data.formData),
      binaryFilePath: data.binaryFilePath,
      preRequestScript: data.preRequestScript,
      useProxy: data.useProxy,
      proxyHost: data.proxyHost ?? '',
      proxyPort: data.proxyPort ?? 8080,
      proxyType: data.proxyType != null
          ? RequestProxyType.values.firstWhere(
              (e) => e.name == data.proxyType,
              orElse: () => RequestProxyType.http,
            )
          : RequestProxyType.http,
      timeoutSeconds: data.timeoutSeconds ?? 30,
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
      headers: Value(_encodeKeyValueItemList(entity.headers)),
      queryParams: Value(_encodeKeyValueItemList(entity.queryParams)),
      bodyType: Value(entity.bodyType.toDbString()),
      bodyContent: Value(entity.bodyContent),
      formData: Value(_encodeFormDataList(entity.formDataItems)),
      binaryFilePath: Value(entity.binaryFilePath),
      preRequestScript: Value(entity.preRequestScript),
      useProxy: Value(entity.useProxy),
      proxyHost: Value(entity.proxyHost),
      proxyPort: Value(entity.proxyPort),
      proxyType: Value(entity.proxyType.name),
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

  /// Parses a JSON-encoded string into a [List<KeyValueItem>].
  ///
  /// Returns an empty list when:
  /// - [jsonString] is empty or `null`.
  /// - The JSON is malformed.
  /// - An element is missing required fields.
  ///
  /// If an `id` field is present in the JSON it is reused; otherwise a new
  /// UUID v4 is generated.
  static List<KeyValueItem> _parseKeyValueItemList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((item) {
            final map = item as Map<String, dynamic>;
            return KeyValueItem(
              key: map['key'] as String? ?? '',
              value: map['value'] as String? ?? '',
              isEnabled: map['enabled'] as bool? ?? true,
              id: map['id'] as String? ?? _uuid.v4(),
            );
          })
          .toList();
    } catch (_) {
      // Malformed JSON – return an empty list instead of crashing.
      return [];
    }
  }

  /// Serialises a [List<KeyValueItem>] into a JSON string.
  static String _encodeKeyValueItemList(List<KeyValueItem> pairs) {
    final encoded = pairs
        .map((kv) => {
              'id': kv.id,
              'key': kv.key,
              'value': kv.value,
              'enabled': kv.isEnabled,
            })
        .toList();
    return json.encode(encoded);
  }

  /// Parses a JSON-encoded string into a [List<FormDataItem>].
  ///
  /// Returns an empty list when:
  /// - [jsonString] is empty or `null`.
  /// - The JSON is malformed.
  /// - An element is missing required fields.
  ///
  /// If an `id` field is present in the JSON it is reused; otherwise a new
  /// UUID v4 is generated.
  static List<FormDataItem> _parseFormDataList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return decoded
          .map((item) {
            final map = item as Map<String, dynamic>;
            return FormDataItem(
              key: map['key'] as String? ?? '',
              value: map['value'] as String? ?? '',
              isFile: map['isFile'] as bool? ?? false,
              filePath: map['filePath'] as String? ?? '',
              fileName: map['fileName'] as String? ?? '',
              contentType: map['contentType'] as String? ?? '',
              id: map['id'] as String? ?? _uuid.v4(),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Serialises a [List<FormDataItem>] into a JSON string.
  static String _encodeFormDataList(List<FormDataItem> items) {
    final encoded = items
        .map((item) => {
              'id': item.id,
              'key': item.key,
              'value': item.value,
              'isFile': item.isFile,
              'filePath': item.filePath,
              'fileName': item.fileName,
              'contentType': item.contentType,
            })
        .toList();
    return json.encode(encoded);
  }
}
