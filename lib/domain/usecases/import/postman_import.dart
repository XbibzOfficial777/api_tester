/// @file postman_import.dart
/// @brief Use case for importing API requests from a Postman Collection.
///
/// Parses Postman Collection v2.1 JSON format and extracts all items
/// as [ApiRequest] entities. Supports folders (mapped to collection names),
/// request headers, query parameters, body (JSON, form data, URL-encoded,
/// raw), and pre-request/test scripts.
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../entities/api_request.dart';
import '../../entities/form_data_item.dart';
import '../../entities/key_value_item.dart';
import '../usecase.dart';

/// Parameters for the Postman import use case.
class PostmanImportParams {
  /// The raw Postman Collection JSON content.
  final String content;

  /// The workspace ID to assign to all imported requests.
  final String workspaceId;

  /// An optional collection ID to assign to all imported requests.
  final String? collectionId;

  /// Creates parameter object for Postman import.
  ///
  /// [content] - The raw JSON string of the Postman Collection.
  /// [workspaceId] - The target workspace ID.
  /// [collectionId] - Optional collection to assign requests to.
  const PostmanImportParams({
    required this.content,
    required this.workspaceId,
    this.collectionId,
  });
}

/// Parses a Postman Collection v2.1 JSON and extracts all requests.
///
/// Handles:
/// - Nested folder structures (recursively flattens all items).
/// - All header types (key-value, disabled headers).
/// - All body modes: raw, urlencoded, formdata, none.
/// - Query parameters from URL or query parameter array.
/// - Pre-request scripts.
class PostmanImport extends UseCase<List<ApiRequest>, PostmanImportParams> {
  /// UUID generator for creating request IDs.
  static const _uuid = Uuid();

  /// Creates a new [PostmanImport] use case.
  PostmanImport();

  /// Parses the Postman Collection and returns a list of [ApiRequest] entities.
  @override
  Future<List<ApiRequest>> call(PostmanImportParams params) async {
    final jsonData = json.decode(params.content) as Map<String, dynamic>;

    // Validate the Postman Collection format.
    final info = jsonData['info'] as Map<String, dynamic>?;
    if (info == null) {
      throw const FormatException(
        'Invalid Postman Collection: missing "info" field',
      );
    }

    // Postman Collection v2.1 uses "item" at the root level.
    final rootItems = jsonData['item'] as List<dynamic>? ?? [];

    final requests = <ApiRequest>[];
    final now = DateTime.now();

    // Recursively extract all requests from the item tree.
    _extractItems(
      items: rootItems,
      requests: requests,
      workspaceId: params.workspaceId,
      collectionId: params.collectionId,
      now: now,
      folderPath: '',
    );

    return requests;
  }

  /// Recursively processes Postman items, extracting requests and descending into folders.
  ///
  /// [items] - List of Postman items (may be requests or folders).
  /// [requests] - Accumulator list for extracted requests.
  /// [workspaceId] - Workspace ID for all requests.
  /// [collectionId] - Optional collection ID.
  /// [now] - Current timestamp for createdAt/updatedAt.
  /// [folderPath] - Dot-separated path of folder names for context.
  void _extractItems({
    required List<dynamic> items,
    required List<ApiRequest> requests,
    required String workspaceId,
    String? collectionId,
    required DateTime now,
    required String folderPath,
  }) {
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      // A Postman "item" is a folder if it has its own "item" array.
      // It is a request if it has a "request" object.
      if (item.containsKey('item')) {
        // This is a folder/sub-collection.
        final folderName = item['name'] as String? ?? 'Unnamed Folder';
        final newPath =
            folderPath.isEmpty ? folderName : '$folderPath/$folderName';
        final subItems = item['item'] as List<dynamic>? ?? [];
        _extractItems(
          items: subItems,
          requests: requests,
          workspaceId: workspaceId,
          collectionId: collectionId,
          now: now,
          folderPath: newPath,
        );
      } else if (item.containsKey('request')) {
        // This is a request.
        final request = _parsePostmanRequest(
          item: item,
          workspaceId: workspaceId,
          collectionId: collectionId,
          now: now,
          folderPath: folderPath,
        );
        if (request != null) {
          requests.add(request);
        }
      }
    }
  }

  /// Parses a single Postman request item into an [ApiRequest].
  ///
  /// Returns null if the request cannot be parsed (e.g., missing URL).
  ApiRequest? _parsePostmanRequest({
    required Map<String, dynamic> item,
    required String workspaceId,
    String? collectionId,
    required DateTime now,
    required String folderPath,
  }) {
    final name = item['name'] as String? ?? 'Unnamed Request';
    final description = item['description'] as String? ?? '';

    // The request object can be a Map or a String (reference).
    dynamic requestObj = item['request'];
    if (requestObj is String) {
      return null; // Skip request references; we can't resolve them without the full collection.
    }
    if (requestObj is! Map<String, dynamic>) return null;

    // Extract the HTTP method.
    final method = _parseHttpMethod(requestObj['method'] as String? ?? 'GET');

    // Parse the URL - can be a string or a Postman URL object.
    final urlResult = _parseUrl(requestObj['url']);
    if (urlResult == null) return null;
    final (url, queryParams) = urlResult;

    // Parse headers.
    final headers = _parseHeaders(requestObj['header'] as List<dynamic>? ?? []);

    // Parse body.
    final bodyResult = _parseBody(requestObj['body'] as Map<String, dynamic>?);
    final bodyType = bodyResult.$1;
    final bodyContent = bodyResult.$2;
    final formDataItems = bodyResult.$3;

    // Extract pre-request script.
    final script = _extractScript(requestObj);

    // Build the display name with folder context if available.
    final displayName =
        folderPath.isEmpty ? name : '[$folderPath] $name';

    return ApiRequest(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      collectionId: collectionId,
      name: displayName,
      description: description,
      method: method,
      url: url,
      headers: headers,
      queryParams: queryParams,
      bodyType: bodyType,
      bodyContent: bodyContent,
      formDataItems: formDataItems,
      preRequestScript: script.isNotEmpty ? script : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parses the Postman URL, which can be a string or a structured object.
  ///
  /// Returns a tuple of (url string, list of KeyValueItem query params).
  (String, List<KeyValueItem>)? _parseUrl(dynamic url) {
    if (url is String) {
      // Simple string URL - extract query params if present.
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final queryParams = uri.queryParameters.entries
          .where((e) => e.key.isNotEmpty)
          .map((e) => KeyValueItem(
                key: e.key,
                value: e.value,
                isEnabled: true,
                id: _uuid.v4(),
              ))
          .toList();

      // Reconstruct URL without query string.
      final baseUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      ).toString();

      return (baseUrl, queryParams);
    }

    if (url is! Map<String, dynamic>) return null;

    // Structured URL object.
    final protocol = url['protocol'] as String? ?? 'https';
    final host = url['host'] as dynamic;
    final path = url['path'] as dynamic;
    final port = url['port'] as dynamic;
    final rawUrl = url['raw'] as String? ?? '';

    // Build the host string (may be a list like ["api", "example", "com"]).
    String hostStr;
    if (host is List) {
      hostStr = host.join('.');
    } else {
      hostStr = host?.toString() ?? '';
    }

    // Build the path string (may be a list like ["v1", "users"]).
    String pathStr;
    if (path is List) {
      pathStr = '/${path.join('/')}';
    } else {
      pathStr = path?.toString() ?? '';
      if (pathStr.isNotEmpty && !pathStr.startsWith('/')) {
        pathStr = '/$pathStr';
      }
    }

    // Build the full URL.
    final portStr = (port != null && port.toString() != '80' && port.toString() != '443')
        ? ':${port.toString()}'
        : '';

    // Prefer raw URL if available, as it's the most accurate representation.
    String finalUrl;
    if (rawUrl.isNotEmpty) {
      // Use raw URL but strip the query string (we handle that separately).
      final uri = Uri.tryParse(rawUrl);
      if (uri != null) {
        finalUrl = Uri(
          scheme: uri.scheme.isNotEmpty ? uri.scheme : protocol,
          host: uri.host.isNotEmpty ? uri.host : hostStr,
          port: uri.port,
          path: uri.path,
        ).toString();
      } else {
        finalUrl = '$protocol://$hostStr$portStr$pathStr';
      }
    } else {
      finalUrl = '$protocol://$hostStr$portStr$pathStr';
    }

    // Extract query parameters.
    final queryParams = <KeyValueItem>[];
    final queryList = url['query'] as List<dynamic>? ?? [];

    for (final q in queryList) {
      if (q is! Map<String, dynamic>) continue;
      final key = q['key'] as String? ?? '';
      final value = q['value'] as String? ?? '';
      final disabled = q['disabled'] as bool? ?? false;

      if (key.isNotEmpty) {
        queryParams.add(KeyValueItem(
          key: key,
          value: value,
          isEnabled: !disabled,
          id: _uuid.v4(),
        ));
      }
    }

    // Also parse query params from the raw URL if we used it.
    if (rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && uri.queryParameters.isNotEmpty) {
        // Only add query params not already present from the structured object.
        final existingKeys = queryParams.map((q) => q.key).toSet();
        for (final entry in uri.queryParameters.entries) {
          if (!existingKeys.contains(entry.key) && entry.key.isNotEmpty) {
            queryParams.add(KeyValueItem(
              key: entry.key,
              value: entry.value,
              isEnabled: true,
              id: _uuid.v4(),
            ));
          }
        }
      }
    }

    return (finalUrl, queryParams);
  }

  /// Parses Postman headers into a list of [KeyValueItem].
  ///
  /// Postman headers are an array of {key, value, disabled} objects.
  List<KeyValueItem> _parseHeaders(List<dynamic> headers) {
    return headers
        .whereType<Map<String, dynamic>>()
        .map((h) {
          final key = h['key'] as String? ?? '';
          final value = h['value'] as String? ?? '';
          final disabled = h['disabled'] as bool? ?? false;

          if (key.isEmpty) return null;

          return KeyValueItem(
            key: key,
            value: value,
            isEnabled: !disabled,
            id: _uuid.v4(),
          );
        })
        .whereType<KeyValueItem>()
        .toList();
  }

  /// Parses a Postman request body into (BodyType, bodyContent, formDataItems).
  ///
  /// Handles all Postman body modes: raw, urlencoded, formdata, and none.
  (BodyType, String, List<FormDataItem>) _parseBody(
    Map<String, dynamic>? body,
  ) {
    if (body == null) return (BodyType.none, '', []);

    final mode = body['mode'] as String? ?? 'none';
    final options = body['options'] as Map<String, dynamic>? ?? {};

    switch (mode) {
      case 'raw':
        final rawContent = body['raw'] as String? ?? '';
        // Check if there's a language hint in options.
        final rawLanguage =
            (options['raw'] as Map<String, dynamic>?)?['language'] as String?;
        // Postman raw can be JSON, XML, text, etc. We store it all as raw.
        return (BodyType.raw, rawContent, []);

      case 'urlencoded':
        final urlencodedList =
            body['urlencoded'] as List<dynamic>? ?? [];
        final items = _parseFormDataItems(urlencodedList, isFormData: false);
        // Build the URL-encoded string.
        final encoded = items
            .where((f) => f.key.isNotEmpty)
            .map((f) =>
                '${Uri.encodeComponent(f.key)}=${Uri.encodeComponent(f.value)}')
            .join('&');
        return (BodyType.urlEncoded, encoded, []);

      case 'formdata':
        final formList = body['formdata'] as List<dynamic>? ?? [];
        final items = _parseFormDataItems(formList, isFormData: true);
        return (BodyType.formData, '', items);

      case 'file':
        // Postman file mode - treat as binary.
        final fileData = body['file'] as Map<String, dynamic>? ?? {};
        final filePath = fileData['src'] as String? ?? '';
        return (BodyType.binary, '', []);

      case 'none':
      default:
        return (BodyType.none, '', []);
    }
  }

  /// Parses Postman form data items (used for both urlencoded and formdata).
  List<FormDataItem> _parseFormDataItems(
    List<dynamic> items, {
    required bool isFormData,
  }) {
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final key = item['key'] as String? ?? '';
          final value = item['value'] as String? ?? '';
          final type = item['type'] as String? ?? 'text';
          final disabled = item['disabled'] as bool? ?? false;
          final src = item['src'] as String? ?? '';

          final isFile = isFormData && (type == 'file');

          return FormDataItem(
            key: key,
            value: value,
            isFile: isFile,
            filePath: isFile ? (src.isNotEmpty ? src : '') : '',
            fileName: isFile ? (src.split('/').last) : '',
            contentType: '',
            id: _uuid.v4(),
          );
        })
        .toList();
  }

  /// Extracts the pre-request script from a Postman request.
  ///
  /// Postman stores scripts in an event array with a "listen" field.
  String _extractScript(Map<String, dynamic> requestObj) {
    final events = requestObj['event'] as List<dynamic>? ?? [];
    for (final event in events) {
      if (event is! Map<String, dynamic>) continue;
      if (event['listen'] == 'prerequest') {
        final script = event['script'] as Map<String, dynamic>?;
        if (script != null) {
          // Exec is an array of lines in some formats, or a single string.
          final exec = script['exec'];
          if (exec is String) return exec;
          if (exec is List) return exec.join('\n');
        }
      }
    }
    return '';
  }

  /// Parses a Postman method string into the [HttpMethod] enum.
  HttpMethod _parseHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'PATCH':
        return HttpMethod.patch;
      case 'DELETE':
        return HttpMethod.delete;
      case 'HEAD':
        return HttpMethod.head;
      case 'OPTIONS':
        return HttpMethod.options;
      default:
        return HttpMethod.get;
    }
  }
}