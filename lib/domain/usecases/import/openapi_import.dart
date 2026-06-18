/// @file openapi_import.dart
/// @brief Use case for importing API requests from an OpenAPI (Swagger) specification.
///
/// Parses OpenAPI 3.0.x and OpenAPI 2.0 (Swagger) specifications in both
/// JSON and YAML formats. Extracts all endpoints as [ApiRequest] entities
/// with method, URL path, parameters, request body, and headers populated
/// from the schema definitions.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import '../../entities/api_request.dart';
import '../../entities/form_data_item.dart';
import '../../entities/key_value_item.dart';
import '../usecase.dart';

/// Parameters for the OpenAPI import use case.
class OpenApiImportParams {
  /// The raw file content (JSON string or YAML string).
  final String content;

  /// The format of the content. Use 'json' for JSON and 'yaml' for YAML.
  final String format;

  /// An optional workspace ID to assign to all imported requests.
  final String workspaceId;

  /// An optional collection ID to assign to all imported requests.
  final String? collectionId;

  /// Base URL to prepend to all paths. If the OpenAPI spec has a
  /// [servers] or [host] field, that takes precedence.
  final String? baseUrlOverride;

  /// Creates parameter object for OpenAPI import.
  ///
  /// [content] - The raw OpenAPI specification content.
  /// [format] - Either 'json' or 'yaml'.
  /// [workspaceId] - The target workspace ID.
  /// [collectionId] - Optional collection to assign requests to.
  /// [baseUrlOverride] - Optional base URL override.
  const OpenApiImportParams({
    required this.content,
    required this.format,
    required this.workspaceId,
    this.collectionId,
    this.baseUrlOverride,
  });
}

/// Parses an OpenAPI specification and extracts all endpoints as [ApiRequest] entities.
///
/// Supports:
/// - OpenAPI 3.0.x (JSON and YAML)
/// - OpenAPI 2.0 / Swagger (JSON and YAML)
/// - Path parameters, query parameters, headers, and request bodies
/// - Example values from schemas for auto-populating fields
/// - Security schemes (Basic, Bearer, API Key) as headers
class OpenApiImport extends UseCase<List<ApiRequest>, OpenApiImportParams> {
  /// UUID generator for creating request IDs.
  static const _uuid = Uuid();

  /// Creates a new [OpenApiImport] use case.
  OpenApiImport();

  /// Parses the OpenAPI spec and returns a list of [ApiRequest] entities.
  @override
  Future<List<ApiRequest>> call(OpenApiImportParams params) async {
    final Map<String, dynamic> spec;

    // Parse the content based on the specified format.
    if (params.format == 'yaml') {
      final yamlDoc = loadYaml(params.content);
      spec = _yamlToMap(yamlDoc);
    } else {
      spec = json.decode(params.content) as Map<String, dynamic>;
    }

    // Determine the base URL from servers (3.0) or host+basePath (2.0).
    final baseUrl = _extractBaseUrl(spec, params.baseUrlOverride);

    // Extract all paths from the spec.
    final paths = spec['paths'] as Map<String, dynamic>? ?? {};

    final requests = <ApiRequest>[];
    final now = DateTime.now();

    // Iterate over every path and every HTTP method defined on it.
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key as String;
      final pathItem = pathEntry.value as Map<String, dynamic>;

      for (final methodEntry in pathItem.entries) {
        final methodLower = methodEntry.key.toLowerCase();
        // Only process valid HTTP methods.
        if (!['get', 'post', 'put', 'patch', 'delete', 'head', 'options']
            .contains(methodLower)) {
          continue;
        }

        final operation = methodEntry.value as Map<String, dynamic>;

        // Build the request from the operation definition.
        final request = _buildRequest(
          method: methodLower,
          path: path,
          baseUrl: baseUrl,
          operation: operation,
          spec: spec,
          workspaceId: params.workspaceId,
          collectionId: params.collectionId,
          now: now,
        );

        requests.add(request);
      }
    }

    return requests;
  }

  /// Extracts the base URL from the OpenAPI specification.
  ///
  /// In OpenAPI 3.0, uses the first entry in the [servers] array.
  /// In OpenAPI 2.0, combines [host], [basePath], and [schemes].
  /// Falls back to [baseUrlOverride] or an empty string.
  String _extractBaseUrl(
    Map<String, dynamic> spec,
    String? baseUrlOverride,
  ) {
    if (baseUrlOverride != null && baseUrlOverride.isNotEmpty) {
      return baseUrlOverride.replaceAll(RegExp(r'/+$'), '');
    }

    // OpenAPI 3.0.x: use the first server URL.
    if (spec.containsKey('openapi')) {
      final servers = spec['servers'] as List<dynamic>?;
      if (servers != null && servers.isNotEmpty) {
        var url = servers[0]['url'] as String? ?? '';
        // Remove path variable defaults like {variable}.
        url = url.replaceAll(RegExp(r'\{[^}]+\}'), '');
        return url.replaceAll(RegExp(r'/+$'), '');
      }
    }

    // OpenAPI 2.0 (Swagger): combine scheme, host, and basePath.
    if (spec.containsKey('swagger')) {
      final host = spec['host'] as String? ?? 'localhost';
      final basePath = spec['basePath'] as String? ?? '';
      final schemes = spec['schemes'] as List<dynamic>?;
      final scheme =
          (schemes != null && schemes.isNotEmpty) ? schemes[0] as String : 'https';
      return '$scheme://$host$basePath'.replaceAll(RegExp(r'/+$'), '');
    }

    return '';
  }

  /// Builds an [ApiRequest] from a single operation definition.
  ApiRequest _buildRequest({
    required String method,
    required String path,
    required String baseUrl,
    required Map<String, dynamic> operation,
    required Map<String, dynamic> spec,
    required String workspaceId,
    String? collectionId,
    required DateTime now,
  }) {
    final operationId = operation['operationId'] as String? ?? '';
    final summary = operation['summary'] as String? ?? '';
    final description = operation['description'] as String? ?? '';

    // Generate a human-readable name: summary, operationId, or METHOD /path.
    final name = summary.isNotEmpty
        ? summary
        : operationId.isNotEmpty
            ? _camelToTitle(operationId)
            : '${method.toUpperCase()} $path';

    // Build the full URL: baseUrl + path.
    final url = '$baseUrl$path';

    // Extract parameters (path, query, header).
    final queryParams = <KeyValueItem>[];
    final headers = <KeyValueItem>[];
    final pathParams = <String, String>{};

    // Merge path-level and operation-level parameters.
    final allParams = <Map<String, dynamic>>[];
    // Path-level parameters are in the parent path item (not in operation),
    // but we already have the full pathItem. We need to exclude operation fields.
    final pathItem = spec['paths'][path] as Map<String, dynamic>?;
    final pathItemParams = (pathItem?.containsKey('parameters') ?? false)
        ? pathItem!['parameters'] as List
        : <dynamic>[];

    for (final p in pathItemParams) {
      if (p is Map<String, dynamic>) allParams.add(p);
    }

    final opParams = operation['parameters'] as List<dynamic>? ?? [];
    for (final p in opParams) {
      if (p is Map<String, dynamic>) allParams.add(p);
    }

    for (final param in allParams) {
      final pName = param['name'] as String? ?? '';
      final pIn = param['in'] as String? ?? 'query';
      final pExample = _getExampleFromSchema(param);
      final pRequired = param['required'] as bool? ?? false;

      switch (pIn.toLowerCase()) {
        case 'query':
          queryParams.add(KeyValueItem(
            key: pName,
            value: pExample,
            isEnabled: true,
            id: _uuid.v4(),
          ));
          break;
        case 'header':
          headers.add(KeyValueItem(
            key: pName,
            value: pExample,
            isEnabled: true,
            id: _uuid.v4(),
          ));
          break;
        case 'path':
          pathParams[pName] = pExample;
          break;
      }
    }

    // Replace path parameters with example values for a valid URL.
    var resolvedPath = path;
    for (final entry in pathParams.entries) {
      resolvedPath = resolvedPath.replaceAll('{${entry.key}}', entry.value);
    }
    final finalUrl = '$baseUrl$resolvedPath';

    // Extract request body.
    BodyType bodyType = BodyType.none;
    String bodyContent = '';
    List<FormDataItem> formDataItems = [];

    // OpenAPI 3.0: requestBody field.
    if (operation.containsKey('requestBody')) {
      final requestBody = operation['requestBody'] as Map<String, dynamic>;
      final content = requestBody['content'] as Map<String, dynamic>? ?? {};

      if (content.containsKey('application/json')) {
        bodyType = BodyType.raw;
        bodyContent = _extractJsonBody(
          content['application/json'] as Map<String, dynamic>,
          spec,
        );
        headers.add(KeyValueItem(
          key: 'Content-Type',
          value: 'application/json',
          isEnabled: true,
          id: _uuid.v4(),
        ));
      } else if (content.containsKey('application/x-www-form-urlencoded')) {
        bodyType = BodyType.urlEncoded;
        formDataItems = _extractFormOrUrlEncodedBody(
          content['application/x-www-form-urlencoded'] as Map<String, dynamic>,
          spec,
          isFormData: false,
        );
        headers.add(KeyValueItem(
          key: 'Content-Type',
          value: 'application/x-www-form-urlencoded',
          isEnabled: true,
          id: _uuid.v4(),
        ));
      } else if (content.containsKey('multipart/form-data')) {
        bodyType = BodyType.formData;
        formDataItems = _extractFormOrUrlEncodedBody(
          content['multipart/form-data'] as Map<String, dynamic>,
          spec,
          isFormData: true,
        );
        headers.add(KeyValueItem(
          key: 'Content-Type',
          value: 'multipart/form-data',
          isEnabled: true,
          id: _uuid.v4(),
        ));
      }
    }

    // OpenAPI 2.0: body parameters and consumes field.
    if (!operation.containsKey('requestBody') && operation.containsKey('parameters')) {
      final consumes = spec['consumes'] as List<dynamic>? ?? [];
      final hasJsonBody = consumes.contains('application/json') ||
          _hasBodyParam(operation);

      if (hasJsonBody) {
        final bodyParam = _findBodyParam(operation['parameters'] as List);
        if (bodyParam != null) {
          bodyType = BodyType.raw;
          bodyContent = _generateExampleFromSchema2(bodyParam, spec);
          headers.add(KeyValueItem(
            key: 'Content-Type',
            value: 'application/json',
            isEnabled: true,
            id: _uuid.v4(),
          ));
        }
      }
    }

    // Extract security requirements as Authorization header.
    final security = _extractSecurityHeaders(operation, spec);
    headers.addAll(security);

    // Add Accept header based on produces/response content types.
    if (!headers.any((h) => h.key.toLowerCase() == 'accept')) {
      headers.add(KeyValueItem(
        key: 'Accept',
        value: 'application/json',
        isEnabled: true,
        id: _uuid.v4(),
      ));
    }

    // Map the method string to the HttpMethod enum.
    final httpMethod = _parseHttpMethod(method);

    // Build form data items for urlEncoded body type (reuse the same structure).
    if (bodyType == BodyType.urlEncoded && formDataItems.isNotEmpty) {
      // For urlEncoded, we store the values in queryParam-like structure,
      // but the bodyContent will hold the URL-encoded string.
      final parts = formDataItems
          .where((f) => f.key.isNotEmpty)
          .map((f) =>
              '${Uri.encodeComponent(f.key)}=${Uri.encodeComponent(f.value)}')
          .join('&');
      bodyContent = parts;
    }

    return ApiRequest(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      collectionId: collectionId,
      name: name,
      description: description,
      method: httpMethod,
      url: finalUrl,
      headers: headers,
      queryParams: queryParams,
      bodyType: bodyType,
      bodyContent: bodyContent,
      formDataItems: formDataItems,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Extracts a JSON example string from an OpenAPI 3.0 media type object.
  ///
  /// Tries to use the [example] field first, then [examples], then
  /// generates one from the schema.
  String _extractJsonBody(
    Map<String, dynamic> mediaType,
    Map<String, dynamic> spec,
  ) {
    // Direct example on the media type.
    if (mediaType.containsKey('example')) {
      final example = mediaType['example'];
      if (example is String) return example;
      return const JsonEncoder.withIndent('  ').convert(example);
    }

    // Named examples.
    final examples = mediaType['examples'] as Map<String, dynamic>?;
    if (examples != null && examples.isNotEmpty) {
      final firstExample = examples.values.first as Map<String, dynamic>?;
      if (firstExample != null && firstExample.containsKey('value')) {
        final value = firstExample['value'];
        if (value is String) return value;
        return const JsonEncoder.withIndent('  ').convert(value);
      }
    }

    // Generate from schema.
    final schema = mediaType['schema'] as Map<String, dynamic>?;
    if (schema != null) {
      final example = _generateExampleFromSchema(schema, spec);
      return const JsonEncoder.withIndent('  ').convert(example);
    }

    return '';
  }

  /// Generates a JSON-encodable example value from an OpenAPI 3.0 schema.
  dynamic _generateExampleFromSchema(
    Map<String, dynamic> schema,
    Map<String, dynamic> spec,
  ) {
    // If the schema has an explicit example, use it.
    if (schema.containsKey('example')) {
      return schema['example'];
    }

    // Resolve $ref to the actual schema.
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final resolved = _resolveRef(ref, spec);
      if (resolved != null) {
        return _generateExampleFromSchema(resolved, spec);
      }
    }

    final type = schema['type'] as String? ?? 'object';

    switch (type) {
      case 'string':
        if (schema.containsKey('enum')) {
          return (schema['enum'] as List).first;
        }
        if (schema.containsKey('format')) {
          switch (schema['format'] as String) {
            case 'date-time':
              return '2024-01-01T00:00:00.000Z';
            case 'date':
              return '2024-01-01';
            case 'email':
              return 'user@example.com';
            case 'uri':
            case 'url':
              return 'https://example.com';
            case 'uuid':
              return '550e8400-e29b-41d4-a716-446655440000';
            case 'byte':
              return 'U3dhZ2dlciByb2Nrcw==';
            case 'binary':
              return '<binary data>';
            default:
              return 'string';
          }
        }
        return 'string';

      case 'integer':
      case 'number':
        if (schema.containsKey('enum')) {
          return (schema['enum'] as List).first;
        }
        final exampleVal = schema['example'];
        if (exampleVal != null) return exampleVal;
        if (schema.containsKey('minimum')) return schema['minimum'];
        return type == 'integer' ? 0 : 0.0;

      case 'boolean':
        return true;

      case 'array':
        final items = schema['items'] as Map<String, dynamic>?;
        if (items != null) {
          return [_generateExampleFromSchema(items, spec)];
        }
        return <dynamic>[];

      case 'object':
        final properties = schema['properties'] as Map<String, dynamic>? ?? {};
        final required = (schema['required'] as List<dynamic>?)?.cast<String>() ?? [];

        final example = <String, dynamic>{};
        for (final propEntry in properties.entries) {
          final propName = propEntry.key;
          final propSchema = propEntry.value as Map<String, dynamic>;
          example[propName] = _generateExampleFromSchema(propSchema, spec);
        }
        return example;

      default:
        return null;
    }
  }

  /// Generates an example from an OpenAPI 2.0 body parameter schema.
  String _generateExampleFromSchema2(
    Map<String, dynamic> bodyParam,
    Map<String, dynamic> spec,
  ) {
    final schema = bodyParam['schema'] as Map<String, dynamic>?;
    if (schema == null) return '{}';

    final example = _generateExampleFromSchema(schema, spec);
    return const JsonEncoder.withIndent('  ').convert(example);
  }

  /// Extracts form data or URL-encoded fields from a media type object.
  List<FormDataItem> _extractFormOrUrlEncodedBody(
    Map<String, dynamic> mediaType,
    Map<String, dynamic> spec, {
    required bool isFormData,
  }) {
    final items = <FormDataItem>[];
    final schema = mediaType['schema'] as Map<String, dynamic>?;

    if (schema == null) return items;

    // Handle $ref for the schema.
    Map<String, dynamic> resolvedSchema = schema;
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final resolved = _resolveRef(ref, spec);
      if (resolved != null) resolvedSchema = resolved;
    }

    final properties =
        resolvedSchema['properties'] as Map<String, dynamic>? ?? {};
    final required = (resolvedSchema['required'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};

    for (final propEntry in properties.entries) {
      final propName = propEntry.key;
      final propSchema = propEntry.value as Map<String, dynamic>;

      // Determine if this is a file upload (format: binary).
      final isFile = isFormData &&
          (propSchema['type'] == 'string' &&
              propSchema['format'] == 'binary');

      final exampleValue = _getExampleFromSchema(propSchema);

      items.add(FormDataItem(
        key: propName,
        value: exampleValue,
        isFile: isFile,
        filePath: '',
        fileName: isFile ? 'file.bin' : '',
        contentType: isFile ? 'application/octet-stream' : '',
        id: _uuid.v4(),
      ));
    }

    return items;
  }

  /// Extracts security requirements and converts them to Authorization headers.
  ///
  /// Checks operation-level security first, then global security.
  /// Supports Bearer, Basic, and API Key security schemes.
  List<KeyValueItem> _extractSecurityHeaders(
    Map<String, dynamic> operation,
    Map<String, dynamic> spec,
  ) {
    final headers = <KeyValueItem>[];

    // Determine which security requirements apply (operation-level or global).
    List<dynamic>? securityRequirements;
    if (operation.containsKey('security')) {
      securityRequirements = operation['security'] as List<dynamic>;
    } else if (spec.containsKey('security')) {
      securityRequirements = spec['security'] as List<dynamic>;
    }

    if (securityRequirements == null || securityRequirements.isEmpty) {
      return headers;
    }

    // Get the security schemes definitions.
    final securitySchemes = (spec['components'] as Map<String, dynamic>?)
            ?['securitySchemes'] as Map<String, dynamic>? ??
        (spec['securityDefinitions'] as Map<String, dynamic>? ?? {});

    for (final requirement in securityRequirements) {
      if (requirement is! Map<String, dynamic>) continue;

      for (final schemeName in requirement.keys) {
        final scheme =
            securitySchemes[schemeName] as Map<String, dynamic>?;
        if (scheme == null) continue;

        final type = scheme['type'] as String? ?? '';
        final schemeNameIn = scheme['in'] as String?;

        switch (type) {
          case 'http':
            final authScheme = scheme['scheme'] as String? ?? 'bearer';
            if (authScheme.toLowerCase() == 'bearer') {
              headers.add(KeyValueItem(
                key: 'Authorization',
                value: 'Bearer YOUR_TOKEN_HERE',
                isEnabled: true,
                id: _uuid.v4(),
              ));
            } else if (authScheme.toLowerCase() == 'basic') {
              headers.add(KeyValueItem(
                key: 'Authorization',
                value: 'Basic YOUR_CREDENTIALS_HERE',
                isEnabled: true,
                id: _uuid.v4(),
              ));
            }
            break;

          case 'apiKey':
            final name = scheme['name'] as String? ?? 'X-API-Key';
            final location = schemeNameIn ?? 'header';
            if (location == 'header') {
              headers.add(KeyValueItem(
                key: name,
                value: 'YOUR_API_KEY_HERE',
                isEnabled: true,
                id: _uuid.v4(),
              ));
            }
            break;

          case 'oauth2':
            headers.add(KeyValueItem(
              key: 'Authorization',
              value: 'Bearer YOUR_ACCESS_TOKEN_HERE',
              isEnabled: true,
              id: _uuid.v4(),
            ));
            break;

          case 'openIdConnect':
            headers.add(KeyValueItem(
              key: 'Authorization',
              value: 'Bearer YOUR_TOKEN_HERE',
              isEnabled: true,
              id: _uuid.v4(),
            ));
            break;
        }
      }
    }

    return headers;
  }

  /// Resolves a JSON pointer $ref string to the actual schema object.
  ///
  /// Supports both OpenAPI 3.0 (#/components/schemas/...) and
  /// OpenAPI 2.0 (#/definitions/...) reference paths.
  Map<String, dynamic>? _resolveRef(String ref, Map<String, dynamic> spec) {
    if (!ref.startsWith('#/')) return null;

    final parts = ref.substring(2).split('/');
    dynamic current = spec;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current is Map<String, dynamic> ? current : null;
  }

  /// Gets an example value from a parameter or schema definition.
  ///
  /// Tries [example], then [default], then [enum] first value,
  /// then generates a type-appropriate default.
  String _getExampleFromSchema(Map<String, dynamic> schema) {
    if (schema.containsKey('example')) {
      return schema['example']?.toString() ?? '';
    }
    if (schema.containsKey('default')) {
      return schema['default']?.toString() ?? '';
    }
    if (schema.containsKey('enum')) {
      final enums = schema['enum'] as List;
      if (enums.isNotEmpty) return enums.first.toString();
    }
    final type = schema['type'] as String? ?? 'string';
    switch (type) {
      case 'integer':
        return (schema['minimum'] ?? 0).toString();
      case 'number':
        return (schema['minimum'] ?? 0.0).toString();
      case 'boolean':
        return 'true';
      case 'string':
        final format = schema['format'] as String?;
        if (format == 'email') return 'user@example.com';
        if (format == 'date-time') return '2024-01-01T00:00:00Z';
        if (format == 'date') return '2024-01-01';
        if (format == 'uuid') return '550e8400-e29b-41d4-a716-446655440000';
        return '';
      default:
        return '';
    }
  }

  /// Checks if the operation parameters contain a "body" parameter (Swagger 2.0).
  bool _hasBodyParam(Map<String, dynamic> operation) {
    final params = operation['parameters'] as List<dynamic>? ?? [];
    return params.any((p) => (p as Map<String, dynamic>)['in'] == 'body');
  }

  /// Finds the first "in: body" parameter from a parameter list (Swagger 2.0).
  Map<String, dynamic>? _findBodyParam(List<dynamic> params) {
    for (final p in params) {
      final param = p as Map<String, dynamic>;
      if (param['in'] == 'body') return param;
    }
    return null;
  }

  /// Parses an HTTP method string into the [HttpMethod] enum.
  HttpMethod _parseHttpMethod(String method) {
    switch (method.toLowerCase()) {
      case 'get':
        return HttpMethod.get;
      case 'post':
        return HttpMethod.post;
      case 'put':
        return HttpMethod.put;
      case 'patch':
        return HttpMethod.patch;
      case 'delete':
        return HttpMethod.delete;
      case 'head':
        return HttpMethod.head;
      case 'options':
        return HttpMethod.options;
      default:
        return HttpMethod.get;
    }
  }

  /// Converts a camelCase string to a title-case display string.
  ///
  /// Example: "getUserById" -> "Get User By Id"
  String _camelToTitle(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && char.toLowerCase() != char && i > 0) {
        buffer.write(' ');
      }
      if (i == 0) {
        buffer.write(char.toUpperCase());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Recursively converts a YamlMap to a Dart Map<String, dynamic>.
  ///
  /// The yaml package returns YamlMap objects which need to be converted
  /// to standard Dart Maps for JSON-compatible processing.
  Map<String, dynamic> _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml.map((key, value) {
        final k = key.toString();
        if (value is YamlMap) {
          return MapEntry(k, _yamlToMap(value));
        } else if (value is YamlList) {
          return MapEntry(k, _yamlListToList(value));
        }
        return MapEntry(k, value);
      });
    }
    return <String, dynamic>{};
  }

  /// Recursively converts a YamlList to a Dart List<dynamic>.
  List<dynamic> _yamlListToList(YamlList list) {
    return list.map((item) {
      if (item is YamlMap) {
        return _yamlToMap(item);
      } else if (item is YamlList) {
        return _yamlListToList(item);
      }
      return item;
    }).toList();
  }
}